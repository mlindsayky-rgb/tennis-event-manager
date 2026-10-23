// pin-auth — the only place PINs are ever checked or changed.
//
// Browsers never see a PIN hash. Every action runs here with the service role,
// and a successful login hands back a real Supabase session whose
// app_metadata (server-set only, can't be edited by the browser) carries the
// person's role and club. Database access rules read those claims.
//
// Actions (POST JSON { action, ... }):
//   login            { pin }                          -> session + profile
//   resume           {}                               -> profile    (signed in; "stay signed in")
//   verify_admin_pin { pin }                          -> { ok }     (signed in)
//   change_own_pin   { current_pin, new_pin }         -> { ok }     (signed in)
//   set_pin          { kind, ref_id, new_pin|null }   -> { ok }     (signed in, permission-checked)
//   create_director  { name, club_id, feature_access, pin } -> { ok, id } (admin only)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

// Lockout: this many failed PIN tries from one network in the window blocks it.
// Everyone on the club's Wi-Fi shares one network address, so this is set a
// little above "a few" to keep one fumbling person from locking out the room.
const MAX_FAILS_PER_IP = 10;
const MAX_FAILS_GLOBAL = 60; // safety net against a spread-out guessing attack
const WINDOW_MIN = 15;

const STAFF_KINDS = new Set(["admin", "director"]);
type Kind = "admin" | "director" | "coach" | "captain" | "player";
const KINDS: Kind[] = ["admin", "director", "coach", "captain", "player"];

// ── Hashing ────────────────────────────────────────────────────────────────
// v2: HMAC-SHA256 with a server-only secret. The secret lives in the
// app_secrets table (service-role only; generated inside the database, never
// typed or shown anywhere). Legacy hashes (the old browser-side
// "tem_salt_v1_" SHA-256) still verify once, then get upgraded to v2 on that
// successful sign-in.
const enc = new TextEncoder();
const hex = (buf: ArrayBuffer) => Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
async function legacyHash(pin: string) {
  return hex(await crypto.subtle.digest("SHA-256", enc.encode("tem_salt_v1_" + pin)));
}
let cachedPepper: string | null = null;
async function getPepper(): Promise<string> {
  if (cachedPepper) return cachedPepper;
  const svc = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data } = await svc.from("app_secrets").select("value").eq("name", "pin_pepper").maybeSingle();
  if (!data?.value || data.value.length < 32) throw new Error("pin_pepper secret is missing");
  cachedPepper = data.value;
  return cachedPepper;
}
async function v2Hash(pin: string) {
  const pepper = await getPepper();
  const key = await crypto.subtle.importKey("raw", enc.encode(pepper), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return "v2:" + hex(await crypto.subtle.sign("HMAC", key, enc.encode(pin)));
}
async function bothHashes(pin: string) {
  return [await v2Hash(pin), await legacyHash(pin)];
}

function pinShapeOk(pin: unknown, kind: Kind | null): pin is string {
  if (typeof pin !== "string") return false;
  if (kind && STAFF_KINDS.has(kind)) return /^\d{6}$/.test(pin);
  if (kind) return /^\d{4}$/.test(pin);
  return /^\d{4}$|^\d{6}$/.test(pin); // login accepts either length
}

function clientIp(req: Request) {
  return (req.headers.get("x-forwarded-for") || "").split(",")[0].trim() || req.headers.get("x-real-ip") || "unknown";
}

// ── Rate limiting ──────────────────────────────────────────────────────────
async function lockedOut(svc: SupabaseClient, ip: string) {
  const since = new Date(Date.now() - WINDOW_MIN * 60_000).toISOString();
  const [{ count: ipFails }, { count: allFails }] = await Promise.all([
    svc.from("login_attempts").select("id", { count: "exact", head: true }).eq("ip", ip).eq("succeeded", false).gte("at", since),
    svc.from("login_attempts").select("id", { count: "exact", head: true }).eq("succeeded", false).gte("at", since),
  ]);
  return (ipFails ?? 0) >= MAX_FAILS_PER_IP || (allFails ?? 0) >= MAX_FAILS_GLOBAL;
}
async function logAttempt(svc: SupabaseClient, ip: string, succeeded: boolean) {
  // Failures simply age out after the window. A good sign-in deliberately does
  // NOT clear them, or someone who knows one PIN could keep resetting the
  // counter while guessing others.
  await svc.from("login_attempts").insert({ ip, succeeded });
  // Light housekeeping: drop rows older than a day.
  if (Math.random() < 0.05) {
    await svc.from("login_attempts").delete().lt("at", new Date(Date.now() - 86_400_000).toISOString());
  }
}

// ── Credentials ────────────────────────────────────────────────────────────
type Cred = { id: string; kind: Kind; ref_id: string; pin_hash: string; auth_user_id: string | null; pin_digits: number | null; must_change: boolean };
const CRED_COLS = "id,kind,ref_id,pin_hash,auth_user_id,pin_digits,must_change";
async function findCredByPin(svc: SupabaseClient, pin: string): Promise<Cred | null> {
  const { data } = await svc.from("pin_credentials").select(CRED_COLS).in("pin_hash", await bothHashes(pin));
  return (data?.[0] as Cred) ?? null;
}
async function pinTakenByOther(svc: SupabaseClient, pin: string, kind: Kind, refId: string) {
  const { data } = await svc.from("pin_credentials").select("kind,ref_id").in("pin_hash", await bothHashes(pin));
  return (data || []).some((r) => !(r.kind === kind && r.ref_id === refId));
}
// mustChange: true when someone else assigned this PIN — the owner is asked
// to pick their own at their next sign-in.
async function savePin(svc: SupabaseClient, kind: Kind, refId: string, pin: string | null, mustChange = false) {
  if (pin === null) {
    await svc.from("pin_credentials").delete().eq("kind", kind).eq("ref_id", refId);
  } else {
    const pin_hash = await v2Hash(pin);
    const { error } = await svc.from("pin_credentials")
      .upsert({ kind, ref_id: refId, pin_hash, pin_digits: pin.length, must_change: mustChange, updated_at: new Date().toISOString() }, { onConflict: "kind,ref_id" });
    if (error) throw error;
  }
  // Keep the "PIN set?" flags the screens show in sync.
  const isSet = pin !== null;
  if (kind === "coach") await svc.from("coaches").update({ pin_set: isSet }).eq("id", refId);
  if (kind === "captain") await svc.from("league_teams").update({ captain_pin_set: isSet }).eq("id", refId);
  if (kind === "player") await svc.from("players").update({ pin_set: isSet }).eq("id", refId);
}

// ── Profiles & claims ──────────────────────────────────────────────────────
// Returns the same shapes the app's old browser-side login used, plus the
// claims that go into the signed session. null = this credential can't sign in.
async function buildProfile(svc: SupabaseClient, cred: Cred) {
  if (cred.kind === "admin") {
    return { claims: { app_role: "admin" }, profile: { role: "admin" } };
  }
  if (cred.kind === "director") {
    const { data: dir } = await svc.from("directors")
      .select("id,name,club_id,is_active,feature_access,clubs(name,primary_color,secondary_color,accent_color)")
      .eq("id", cred.ref_id).maybeSingle();
    if (!dir || !dir.is_active) return null;
    return {
      claims: { app_role: "director", director_id: dir.id, club_id: dir.club_id, feature_access: dir.feature_access || ["events"] },
      profile: { role: "director", director: dir },
    };
  }
  if (cred.kind === "coach") {
    const { data: coach } = await svc.from("coaches").select("id,name,phone,email").eq("id", cred.ref_id).maybeSingle();
    if (!coach) return null;
    const { data: teams } = await svc.from("league_teams")
      .select("id,name,league_id,club_id,clubs(name,primary_color,secondary_color,accent_color)").eq("coach_id", coach.id);
    return {
      claims: {
        app_role: "coach", coach_id: coach.id,
        team_ids: (teams || []).map((t) => t.id),
        league_ids: [...new Set((teams || []).map((t) => t.league_id))],
      },
      profile: { role: "coach", coach, teams: teams || [] },
    };
  }
  if (cred.kind === "captain") {
    const { data: team } = await svc.from("league_teams")
      .select("*, leagues(name,format), clubs(name,primary_color,secondary_color,accent_color)").eq("id", cred.ref_id).maybeSingle();
    if (!team) return null;
    for (const k of ["captain_pin_hash", "coach_pin_hash"]) delete (team as Record<string, unknown>)[k];
    const { data: captainRow } = await svc.from("league_team_players")
      .select("player_id,players(roster_name)").eq("team_id", team.id).eq("is_captain", true).maybeSingle();
    return {
      claims: { app_role: "captain", team_id: team.id, league_ids: [team.league_id], club_id: team.club_id, player_id: captainRow?.player_id ?? null },
      profile: { role: "captain", team, captainRow },
    };
  }
  // player
  const { data: player } = await svc.from("players").select("id,roster_name,is_active").eq("id", cred.ref_id).maybeSingle();
  if (!player || !player.is_active) return null;
  return { claims: { app_role: "player", player_id: player.id }, profile: { role: "player", player } };
}

// One hidden sign-in account per PIN holder. Nobody ever sees or uses its
// email; it exists only so Supabase can issue a real, signed session.
async function ensureAuthUser(svc: SupabaseClient, cred: Cred, claims: Record<string, unknown>) {
  const email = `${cred.kind}.${cred.ref_id}@pin-auth.invalid`;
  if (cred.auth_user_id) {
    const { error } = await svc.auth.admin.updateUserById(cred.auth_user_id, { app_metadata: claims });
    if (!error) return email;
  }
  let userId: string | null = null;
  const created = await svc.auth.admin.createUser({ email, email_confirm: true, app_metadata: claims });
  if (created.data?.user) userId = created.data.user.id;
  else {
    // Already exists (e.g. credential row was re-created): look it up.
    const { data } = await svc.auth.admin.listUsers({ page: 1, perPage: 1000 });
    userId = data?.users.find((u) => u.email === email)?.id ?? null;
    if (!userId) throw created.error ?? new Error("Could not create sign-in account");
    await svc.auth.admin.updateUserById(userId, { app_metadata: claims });
  }
  await svc.from("pin_credentials").update({ auth_user_id: userId }).eq("id", cred.id);
  return email;
}

async function issueSession(url: string, anonKey: string, svc: SupabaseClient, email: string) {
  const { data: link, error } = await svc.auth.admin.generateLink({ type: "magiclink", email });
  if (error || !link?.properties?.hashed_token) throw error ?? new Error("Could not start session");
  const pub = createClient(url, anonKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data, error: vErr } = await pub.auth.verifyOtp({ type: "magiclink", token_hash: link.properties.hashed_token });
  if (vErr || !data.session) throw vErr ?? new Error("Could not start session");
  return { access_token: data.session.access_token, refresh_token: data.session.refresh_token };
}

// The signed-in caller, verified by Supabase (never trusted from the body).
async function callerUser(svc: SupabaseClient, req: Request) {
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data } = await svc.auth.getUser(token);
  return data?.user ?? null;
}
async function callerClaims(svc: SupabaseClient, req: Request): Promise<Record<string, any> | null> {
  const user = await callerUser(svc, req);
  return (user?.app_metadata?.app_role ? (user.app_metadata as Record<string, any>) : null);
}

// Who may set/clear whose PIN.
async function maySetPin(svc: SupabaseClient, me: Record<string, any>, kind: Kind, refId: string) {
  const role = me.app_role;
  if (role === "admin") return true;
  if (role === "director") {
    if (kind === "admin") return false;
    if (kind === "director") return refId === me.director_id;
    return true; // coaches, captains, players
  }
  if (role === "coach" && kind === "captain") {
    return Array.isArray(me.team_ids) && me.team_ids.includes(refId);
  }
  return false;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const svc = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const ip = clientIp(req);

  let body: Record<string, any>;
  try { body = await req.json(); } catch { return json({ error: "Bad request" }, 400); }

  try {
    switch (body.action) {
      case "login": {
        if (await lockedOut(svc, ip)) return json({ error: "Too many tries. Wait 15 minutes and try again.", locked: true }, 429);
        if (!pinShapeOk(body.pin, null)) { await logAttempt(svc, ip, false); return json({ error: "Incorrect PIN" }, 401); }
        const cred = await findCredByPin(svc, body.pin);
        const built = cred ? await buildProfile(svc, cred) : null;
        if (!cred || !built) { await logAttempt(svc, ip, false); return json({ error: "Incorrect PIN" }, 401); }
        // Upgrade a legacy hash now that we know the PIN, and remember its length.
        if (!cred.pin_hash.startsWith("v2:") || cred.pin_digits !== body.pin.length) {
          await svc.from("pin_credentials").update({ pin_hash: await v2Hash(body.pin), pin_digits: body.pin.length }).eq("id", cred.id);
        }
        const email = await ensureAuthUser(svc, cred, built.claims);
        const session = await issueSession(url, anonKey, svc, email);
        await logAttempt(svc, ip, true);
        if (cred.kind === "director") {
          await svc.from("directors").update({ last_login_at: new Date().toISOString() }).eq("id", cred.ref_id);
        }
        // Admin/directors still on a 4-digit PIN must pick a 6-digit one now,
        // and anyone signing in with a PIN someone else assigned picks their own.
        const must_upgrade_pin = STAFF_KINDS.has(cred.kind) && body.pin.length !== 6;
        return json({ session, profile: built.profile, must_upgrade_pin, must_change_pin: !!cred.must_change });
      }

      case "resume": {
        // Re-open the app from a saved session. Rebuilds the profile from
        // current data (so a deactivated director or player is turned away)
        // and refreshes the session's claims.
        const user = await callerUser(svc, req);
        if (!user) return json({ error: "Not signed in" }, 401);
        const { data: cred } = await svc.from("pin_credentials")
          .select(CRED_COLS).eq("auth_user_id", user.id).maybeSingle();
        const built = cred ? await buildProfile(svc, cred as Cred) : null;
        if (!cred || !built) return json({ error: "Please sign in again." }, 401);
        await svc.auth.admin.updateUserById(user.id, { app_metadata: built.claims });
        const must_upgrade_pin = STAFF_KINDS.has(cred.kind) && cred.pin_digits !== 6;
        return json({ profile: built.profile, must_upgrade_pin, must_change_pin: !!(cred as Cred).must_change });
      }

      case "verify_admin_pin": {
        const me = await callerClaims(svc, req);
        if (!me) return json({ error: "Not signed in" }, 401);
        if (await lockedOut(svc, ip)) return json({ error: "Too many tries. Wait 15 minutes and try again.", locked: true }, 429);
        const cred = typeof body.pin === "string" ? await findCredByPin(svc, body.pin) : null;
        const ok = !!cred && cred.kind === "admin";
        await logAttempt(svc, ip, ok);
        return json({ ok });
      }

      case "change_own_pin": {
        const me = await callerClaims(svc, req);
        if (!me) return json({ error: "Not signed in" }, 401);
        const ref: [Kind, string] | null =
          me.app_role === "admin" ? ["admin", ""] :
          me.app_role === "director" ? ["director", me.director_id] :
          me.app_role === "coach" ? ["coach", me.coach_id] :
          me.app_role === "captain" ? ["captain", me.team_id] :
          me.app_role === "player" ? ["player", me.player_id] : null;
        if (!ref) return json({ error: "Not allowed" }, 403);
        if (await lockedOut(svc, ip)) return json({ error: "Too many tries. Wait 15 minutes and try again.", locked: true }, 429);
        const cur = typeof body.current_pin === "string" ? await findCredByPin(svc, body.current_pin) : null;
        const isMine = !!cur && cur.kind === ref[0] && (ref[0] === "admin" || cur.ref_id === ref[1]);
        if (!isMine) { await logAttempt(svc, ip, false); return json({ error: "Current PIN incorrect." }, 400); }
        const kind = cur!.kind, refId = cur!.ref_id;
        if (body.new_pin === body.current_pin) {
          return json({ error: "Pick a new PIN that's different from your current one." }, 400);
        }
        if (!pinShapeOk(body.new_pin, kind)) {
          return json({ error: STAFF_KINDS.has(kind) ? "PIN must be 6 digits." : "PIN must be 4 digits." }, 400);
        }
        if (await pinTakenByOther(svc, body.new_pin, kind, refId)) {
          return json({ error: "That PIN is already in use by someone else — pick a different one." }, 409);
        }
        await savePin(svc, kind, refId, body.new_pin);
        await logAttempt(svc, ip, true);
        return json({ ok: true });
      }

      case "set_pin": {
        const me = await callerClaims(svc, req);
        if (!me) return json({ error: "Not signed in" }, 401);
        const kind = body.kind as Kind, refId = String(body.ref_id || "");
        if (!KINDS.includes(kind) || kind === "admin" || !refId) return json({ error: "Bad request" }, 400);
        if (!(await maySetPin(svc, me, kind, refId))) return json({ error: "Not allowed" }, 403);
        if (body.new_pin === null) { await savePin(svc, kind, refId, null); return json({ ok: true }); }
        if (!pinShapeOk(body.new_pin, kind)) {
          return json({ error: STAFF_KINDS.has(kind) ? "PIN must be 6 digits." : "PIN must be 4 digits." }, 400);
        }
        if (await pinTakenByOther(svc, body.new_pin, kind, refId)) {
          return json({ error: "That PIN is already in use by someone else — pick a different one." }, 409);
        }
        const settingOwn = kind === "director" && refId === me.director_id;
        await savePin(svc, kind, refId, body.new_pin, !settingOwn);
        return json({ ok: true });
      }

      case "create_director": {
        const me = await callerClaims(svc, req);
        if (me?.app_role !== "admin") return json({ error: "Not allowed" }, 403);
        const name = String(body.name || "").trim();
        if (!name || !body.club_id) return json({ error: "Name and club required." }, 400);
        if (!pinShapeOk(body.pin, "director")) return json({ error: "PIN must be 6 digits." }, 400);
        const id = crypto.randomUUID();
        if (await pinTakenByOther(svc, body.pin, "director", id)) {
          return json({ error: "That PIN is already in use by someone else — pick a different one." }, 409);
        }
        // directors.pin_hash is a legacy NOT NULL column; the real PIN lives in pin_credentials.
        const { error } = await svc.from("directors").insert({
          id, name, club_id: body.club_id, feature_access: body.feature_access || ["events"],
          pin_hash: "moved-to-pin_credentials", supabase_auth_uid: crypto.randomUUID(),
        });
        if (error) return json({ error: error.message }, 400);
        await savePin(svc, "director", id, body.pin, true);
        return json({ ok: true, id });
      }

      default:
        return json({ error: "Unknown action" }, 400);
    }
  } catch (e) {
    console.error("pin-auth error:", e);
    return json({ error: "Something went wrong. Please try again." }, 500);
  }
});

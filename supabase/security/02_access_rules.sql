-- Tennis Event Manager: real access rules (replace the old allow-everyone rules).
-- Who is signed in comes from the server-issued session (app_metadata; see the
-- auth_* helpers). Browsers that aren't signed in ("anon") only get read access
-- to what the public TV / team / results pages show.

CREATE OR REPLACE FUNCTION public.auth_team_ids() RETURNS uuid[] LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT coalesce(array(SELECT jsonb_array_elements_text(auth_app() -> 'team_ids'))::uuid[], '{}')
          || CASE WHEN auth_app() ->> 'team_id' IS NOT NULL THEN ARRAY[(auth_app() ->> 'team_id')::uuid] ELSE '{}'::uuid[] END $$;
CREATE OR REPLACE FUNCTION public.auth_league_ids() RETURNS uuid[] LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT coalesce(array(SELECT jsonb_array_elements_text(auth_app() -> 'league_ids'))::uuid[], '{}') $$;
CREATE OR REPLACE FUNCTION public.is_signed_in() RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT auth_role() IS NOT NULL $$;
CREATE OR REPLACE FUNCTION public.is_staff() RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT coalesce(auth_role() IN ('admin','director'), false) $$;
CREATE OR REPLACE FUNCTION public.is_team_role() RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT coalesce(auth_role() IN ('coach','captain'), false) $$;
-- Admin: any event. Director: only events at their own club.
CREATE OR REPLACE FUNCTION public.can_edit_event(eid uuid) RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT auth_is_admin() OR (auth_role() = 'director' AND EXISTS (SELECT 1 FROM events e WHERE e.id = eid AND e.club_id = auth_club_id())) $$;
CREATE OR REPLACE FUNCTION public.can_edit_club_row(cid uuid) RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT auth_is_admin() OR (auth_role() = 'director' AND cid = auth_club_id()) $$;
-- Staff: any league. Coach/captain: leagues they have a team in.
CREATE OR REPLACE FUNCTION public.can_work_league(lid uuid) RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT is_staff() OR (is_team_role() AND lid = ANY (auth_league_ids())) $$;
CREATE OR REPLACE FUNCTION public.can_work_match(mid uuid) RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT is_staff() OR (is_team_role() AND EXISTS (SELECT 1 FROM league_matches m WHERE m.id = mid AND m.league_id = ANY (auth_league_ids()))) $$;

-- Remove every existing rule (they all included allow-everyone).
DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public' LOOP
    EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- p(table, read, insert, update, delete): read = 'public' | 'signed' | an expression.
CREATE OR REPLACE FUNCTION pg_temp.p(t text, rd text, ins text, upd text, del text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF rd = 'public' THEN
    -- Not signed in: what the public pages show (column limits are set below).
    -- Signed in: must have a real role from the PIN login; an account made any
    -- other way (e.g. Supabase's own sign-up) gets nothing.
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO anon USING (true)', t||'_public_read', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.is_signed_in())', t||'_read', t);
  ELSIF rd = 'signed' THEN
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.is_signed_in())', t||'_read', t);
  ELSE
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (%s)', t||'_read', t, rd);
  END IF;
  EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK (%s)', t||'_insert', t, ins);
  EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING (%s) WITH CHECK (%s)', t||'_update', t, upd, upd);
  EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING (%s)', t||'_delete', t, del);
END $f$;

SELECT pg_temp.p('app_settings', 'public', 'public.is_staff()', 'public.is_staff()', 'public.auth_is_admin()');
SELECT pg_temp.p('clubs', 'public', 'public.auth_is_admin()', 'public.can_edit_club_row(id)', 'public.auth_is_admin()');
SELECT pg_temp.p('directors', 'signed', 'public.auth_is_admin()', 'public.auth_is_admin()', 'public.auth_is_admin()');
SELECT pg_temp.p('coaches', 'signed', 'public.is_staff()', 'public.is_staff()', 'public.is_staff()');
SELECT pg_temp.p('events', 'public', 'public.can_edit_club_row(club_id)', 'public.can_edit_club_row(club_id)', 'public.can_edit_club_row(club_id)');
SELECT pg_temp.p('event_templates', 'signed', 'public.can_edit_club_row(club_id)', 'public.can_edit_club_row(club_id)', 'public.can_edit_club_row(club_id)');
SELECT pg_temp.p('rounds', 'public', 'public.can_edit_event(event_id)', 'public.can_edit_event(event_id)', 'public.can_edit_event(event_id)');
SELECT pg_temp.p('teams', 'public', 'public.can_edit_event(event_id)', 'public.can_edit_event(event_id)', 'public.can_edit_event(event_id)');
SELECT pg_temp.p('event_players', 'public', 'public.can_edit_event(event_id)', 'public.can_edit_event(event_id)', 'public.can_edit_event(event_id)');
SELECT pg_temp.p('event_notes', 'signed', 'public.can_edit_event(event_id)', 'public.can_edit_event(event_id)', 'public.can_edit_event(event_id)');
SELECT pg_temp.p('draws', 'public', 'public.can_edit_event(event_id)', 'public.can_edit_event(event_id)', 'public.can_edit_event(event_id)');
SELECT pg_temp.p('pairings', 'public', 'public.can_edit_event((SELECT r.event_id FROM public.rounds r WHERE r.id = round_id))', 'public.can_edit_event((SELECT r.event_id FROM public.rounds r WHERE r.id = round_id))', 'public.can_edit_event((SELECT r.event_id FROM public.rounds r WHERE r.id = round_id))');
SELECT pg_temp.p('scores', 'public', 'public.can_edit_event((SELECT r.event_id FROM public.pairings x JOIN public.rounds r ON r.id = x.round_id WHERE x.id = pairing_id))', 'public.can_edit_event((SELECT r.event_id FROM public.pairings x JOIN public.rounds r ON r.id = x.round_id WHERE x.id = pairing_id))', 'public.can_edit_event((SELECT r.event_id FROM public.pairings x JOIN public.rounds r ON r.id = x.round_id WHERE x.id = pairing_id))');
SELECT pg_temp.p('sitout_log', 'public', 'public.can_edit_event((SELECT ep.event_id FROM public.event_players ep WHERE ep.id = event_player_id))', 'public.can_edit_event((SELECT ep.event_id FROM public.event_players ep WHERE ep.id = event_player_id))', 'public.can_edit_event((SELECT ep.event_id FROM public.event_players ep WHERE ep.id = event_player_id))');
SELECT pg_temp.p('team_players', 'public', 'public.can_edit_event((SELECT tm.event_id FROM public.teams tm WHERE tm.id = team_id))', 'public.can_edit_event((SELECT tm.event_id FROM public.teams tm WHERE tm.id = team_id))', 'public.can_edit_event((SELECT tm.event_id FROM public.teams tm WHERE tm.id = team_id))');
SELECT pg_temp.p('draw_entries', 'public', 'public.can_edit_event((SELECT d.event_id FROM public.draws d WHERE d.id = draw_id))', 'public.can_edit_event((SELECT d.event_id FROM public.draws d WHERE d.id = draw_id))', 'public.can_edit_event((SELECT d.event_id FROM public.draws d WHERE d.id = draw_id))');
SELECT pg_temp.p('draw_matches', 'public', 'public.can_edit_event((SELECT d.event_id FROM public.draws d WHERE d.id = draw_id))', 'public.can_edit_event((SELECT d.event_id FROM public.draws d WHERE d.id = draw_id))', 'public.can_edit_event((SELECT d.event_id FROM public.draws d WHERE d.id = draw_id))');
SELECT pg_temp.p('leagues', 'public', 'public.is_staff()', 'public.is_staff()', 'public.is_staff()');
SELECT pg_temp.p('league_teams', 'public', 'public.is_staff()', 'public.is_staff()', 'public.is_staff()');
SELECT pg_temp.p('league_matches', 'public', 'public.is_staff()', 'public.is_staff()', 'public.is_staff()');
SELECT pg_temp.p('court_results', 'public', 'public.can_work_match(match_id)', 'public.can_work_match(match_id)', 'public.can_work_match(match_id)');
SELECT pg_temp.p('league_team_players', 'public', '(public.is_staff() OR (public.auth_role() = ''coach'' AND team_id = ANY (public.auth_team_ids())))', '(public.is_staff() OR (public.auth_role() = ''coach'' AND team_id = ANY (public.auth_team_ids())))', '(public.is_staff() OR (public.auth_role() = ''coach'' AND team_id = ANY (public.auth_team_ids())))');
SELECT pg_temp.p('league_sub_pool', 'signed', '(public.can_work_league(league_id) OR (public.auth_role() = ''player'' AND player_id = public.auth_player_id()))', '(public.can_work_league(league_id) OR (public.auth_role() = ''player'' AND player_id = public.auth_player_id()))', '(public.can_work_league(league_id) OR (public.auth_role() = ''player'' AND player_id = public.auth_player_id()))');
SELECT pg_temp.p('league_interested_subs', 'signed', '(public.can_work_league(league_id) OR (public.auth_role() = ''player'' AND player_id = public.auth_player_id()))', '(public.can_work_league(league_id) OR (public.auth_role() = ''player'' AND player_id = public.auth_player_id()))', '(public.can_work_league(league_id) OR (public.auth_role() = ''player'' AND player_id = public.auth_player_id()))');
SELECT pg_temp.p('players', 'public', '(public.is_staff() OR public.is_team_role())', '(public.is_staff() OR public.is_team_role())', 'public.auth_is_admin()');
SELECT pg_temp.p('player_clubs', 'signed', '(public.is_staff() OR public.is_team_role())', '(public.is_staff() OR public.is_team_role())', 'public.is_staff()');
SELECT pg_temp.p('player_ratings', 'signed', '(public.is_staff() OR public.is_team_role())', 'public.is_staff()', 'public.is_staff()');
SELECT pg_temp.p('player_notes', 'signed', 'public.is_staff()', 'public.is_staff()', 'public.is_staff()');
SELECT pg_temp.p('player_constraints', 'signed', 'public.is_staff()', 'public.is_staff()', 'public.is_staff()');
SELECT pg_temp.p('messages', 'signed', 'public.is_signed_in()', 'public.is_staff()', 'public.is_staff()');
SELECT pg_temp.p('message_recipients', 'signed', 'public.is_signed_in()', 'public.is_signed_in()', 'public.is_staff()');
SELECT pg_temp.p('notifications', '(public.auth_is_admin() OR director_id = public.auth_director_id())', 'public.is_staff()', '(public.auth_is_admin() OR director_id = public.auth_director_id())', 'public.auth_is_admin()');

-- admin_config, pin_credentials, login_attempts, app_secrets: no rules, so only
-- the server function (service role) can touch them.

-- Table permissions. Not-signed-in browsers can only read. Nobody can TRUNCATE
-- from a browser (TRUNCATE ignores row rules, so it has to be revoked).
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM authenticated;
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.admin_config FROM anon, authenticated;
-- Public pages get names only, never contact details or PIN columns.
REVOKE SELECT ON public.players FROM anon;
GRANT SELECT (id, roster_name) ON public.players TO anon;
REVOKE SELECT ON public.league_teams FROM anon;
GRANT SELECT (id, league_id, name, club_id, coach_name, coach_id, time_slot_day, time_slot_time, created_at,
  avatar_url, avatar_color, court_count, abbreviation, team_code) ON public.league_teams TO anon;

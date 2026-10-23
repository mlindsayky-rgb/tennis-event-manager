-- Go-live stage 1: server-checked PIN login. Safe to run while the old open
-- rules are still in place — nothing that works today stops working.

-- Private PIN store + sign-in attempt log + server secret. New tables get no
-- browser access in this project unless granted, and none is granted here.
CREATE TABLE public.pin_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL CHECK (kind IN ('admin','director','coach','captain','player')),
  ref_id uuid NOT NULL,
  pin_hash text NOT NULL,
  pin_digits smallint,
  auth_user_id uuid,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (kind, ref_id),
  UNIQUE (pin_hash)
);
CREATE INDEX pin_credentials_auth_user_idx ON public.pin_credentials (auth_user_id);
CREATE TABLE public.login_attempts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ip text NOT NULL,
  succeeded boolean NOT NULL,
  at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX login_attempts_ip_at_idx ON public.login_attempts (ip, at DESC);
CREATE INDEX login_attempts_at_idx ON public.login_attempts (at DESC);
CREATE TABLE public.app_secrets (
  name text PRIMARY KEY,
  value text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.pin_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_secrets ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pin_credentials, public.login_attempts TO service_role;
GRANT SELECT ON public.app_secrets TO service_role;
INSERT INTO public.app_secrets (name, value) VALUES ('pin_pepper', encode(extensions.gen_random_bytes(32), 'hex'));

-- Copy every existing PIN in, unchanged; each is upgraded on its owner's next sign-in.
INSERT INTO public.pin_credentials (kind, ref_id, pin_hash)
SELECT 'admin', id, pin_hash FROM public.admin_config WHERE pin_hash IS NOT NULL
UNION ALL SELECT 'director', id, pin_hash FROM public.directors WHERE pin_hash IS NOT NULL
UNION ALL SELECT 'coach', id, pin_hash FROM public.coaches WHERE pin_hash IS NOT NULL
UNION ALL SELECT 'captain', id, captain_pin_hash FROM public.league_teams WHERE captain_pin_hash IS NOT NULL
UNION ALL SELECT 'player', id, pin_hash FROM public.players WHERE pin_hash IS NOT NULL;

-- "PIN set?" flags so screens never need to read a hash.
ALTER TABLE public.coaches ADD COLUMN pin_set boolean NOT NULL DEFAULT false;
ALTER TABLE public.league_teams ADD COLUMN captain_pin_set boolean NOT NULL DEFAULT false;
ALTER TABLE public.players ADD COLUMN pin_set boolean NOT NULL DEFAULT false;
UPDATE public.coaches SET pin_set = true WHERE pin_hash IS NOT NULL;
UPDATE public.league_teams SET captain_pin_set = true WHERE captain_pin_hash IS NOT NULL;
UPDATE public.players SET pin_set = true WHERE pin_hash IS NOT NULL;

-- Who-is-signed-in helpers (read from the server-set part of the session).
CREATE OR REPLACE FUNCTION public.auth_app() RETURNS jsonb LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT coalesce(auth.jwt() -> 'app_metadata', '{}'::jsonb) $$;
CREATE OR REPLACE FUNCTION public.auth_role() RETURNS text LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT public.auth_app() ->> 'app_role' $$;
CREATE OR REPLACE FUNCTION public.auth_is_admin() RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT coalesce(public.auth_role() = 'admin', false) $$;
CREATE OR REPLACE FUNCTION public.auth_club_id() RETURNS uuid LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT (public.auth_app() ->> 'club_id')::uuid $$;
CREATE OR REPLACE FUNCTION public.auth_director_id() RETURNS uuid LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT (public.auth_app() ->> 'director_id')::uuid $$;
CREATE OR REPLACE FUNCTION public.auth_coach_id() RETURNS uuid LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT (public.auth_app() ->> 'coach_id')::uuid $$;
CREATE OR REPLACE FUNCTION public.auth_team_id() RETURNS uuid LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT (public.auth_app() ->> 'team_id')::uuid $$;
CREATE OR REPLACE FUNCTION public.auth_player_id() RETURNS uuid LANGUAGE sql STABLE SET search_path TO 'public','pg_temp'
AS $$ SELECT (public.auth_app() ->> 'player_id')::uuid $$;

-- The login function (service role) reads profiles and keeps flags in sync.
GRANT SELECT ON public.admin_config, public.directors, public.coaches, public.league_teams, public.players,
  public.clubs, public.leagues, public.league_team_players TO service_role;
GRANT UPDATE ON public.directors, public.coaches, public.league_teams, public.players TO service_role;
GRANT INSERT ON public.directors TO service_role;

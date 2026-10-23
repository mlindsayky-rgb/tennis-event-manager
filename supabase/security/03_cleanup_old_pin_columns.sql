-- Go-live stage 3 (after the new app is live and everyone can sign in):
-- blank out the old PIN columns so no copy of a PIN hash is left where a
-- browser could ever read it. The real PINs live in pin_credentials.
UPDATE public.admin_config SET pin_hash = 'moved-to-pin_credentials' WHERE pin_hash <> 'moved-to-pin_credentials';
UPDATE public.directors SET pin_hash = 'moved-to-pin_credentials' WHERE pin_hash <> 'moved-to-pin_credentials';
UPDATE public.coaches SET pin_hash = NULL WHERE pin_hash IS NOT NULL;
UPDATE public.league_teams SET captain_pin_hash = NULL WHERE captain_pin_hash IS NOT NULL;
UPDATE public.league_teams SET coach_pin_hash = NULL WHERE coach_pin_hash IS NOT NULL;
UPDATE public.players SET pin_hash = NULL WHERE pin_hash IS NOT NULL;

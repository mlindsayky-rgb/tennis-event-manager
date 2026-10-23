-- UNDO for stage 2 (02_access_rules.sql): restores the exact open rules and
-- table permissions that were live before the change (captured 2026-10-23).
-- Only use this if something important breaks after stage 2.
DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public'
           AND tablename NOT IN ('pin_credentials','login_attempts','app_secrets') LOOP
    EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;
CREATE POLICY admin_config_admin_only ON public.admin_config AS PERMISSIVE FOR ALL TO authenticated USING (auth_is_admin());
CREATE POLICY admin_config_allow_all ON public.admin_config AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY app_settings_allow_all ON public.app_settings AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY clubs_admin_all ON public.clubs AS PERMISSIVE FOR ALL TO authenticated USING (auth_is_admin());
CREATE POLICY clubs_allow_all ON public.clubs AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY clubs_anon_insert ON public.clubs AS PERMISSIVE FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY clubs_anon_select ON public.clubs AS PERMISSIVE FOR SELECT TO anon USING (true);
CREATE POLICY clubs_anon_update ON public.clubs AS PERMISSIVE FOR UPDATE TO anon USING (true);
CREATE POLICY clubs_director_read ON public.clubs AS PERMISSIVE FOR SELECT TO authenticated USING ((id = auth_club_id()));
CREATE POLICY coaches_allow_all ON public.coaches AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY court_results_allow_all ON public.court_results AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY directors_allow_all ON public.directors AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY draw_entries_allow_all ON public.draw_entries AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY draw_entries_director ON public.draw_entries AS PERMISSIVE FOR ALL TO authenticated USING ((draw_id IN ( SELECT d.id
   FROM (draws d
     JOIN events e ON ((e.id = d.event_id)))
  WHERE (e.club_id = auth_club_id()))));
CREATE POLICY draw_matches_allow_all ON public.draw_matches AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY draw_matches_director ON public.draw_matches AS PERMISSIVE FOR ALL TO authenticated USING ((draw_id IN ( SELECT d.id
   FROM (draws d
     JOIN events e ON ((e.id = d.event_id)))
  WHERE (e.club_id = auth_club_id()))));
CREATE POLICY draws_allow_all ON public.draws AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY draws_director ON public.draws AS PERMISSIVE FOR ALL TO authenticated USING ((event_id IN ( SELECT events.id
   FROM events
  WHERE (events.club_id = auth_club_id()))));
CREATE POLICY event_notes_allow_all ON public.event_notes AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY event_notes_director ON public.event_notes AS PERMISSIVE FOR ALL TO authenticated USING ((event_id IN ( SELECT events.id
   FROM events
  WHERE (events.club_id = auth_club_id()))));
CREATE POLICY "Allow anon read event_players" ON public.event_players AS PERMISSIVE FOR SELECT TO anon USING (true);
CREATE POLICY event_players_allow_all ON public.event_players AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY event_players_director ON public.event_players AS PERMISSIVE FOR ALL TO authenticated USING ((event_id IN ( SELECT events.id
   FROM events
  WHERE (events.club_id = auth_club_id()))));
CREATE POLICY event_templates_allow_all ON public.event_templates AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY templates_admin_all ON public.event_templates AS PERMISSIVE FOR ALL TO authenticated USING (auth_is_admin());
CREATE POLICY templates_director_own ON public.event_templates AS PERMISSIVE FOR ALL TO authenticated USING ((club_id = auth_club_id()));
CREATE POLICY "Allow anon read events" ON public.events AS PERMISSIVE FOR SELECT TO anon USING (true);
CREATE POLICY events_admin_all ON public.events AS PERMISSIVE FOR ALL TO authenticated USING (auth_is_admin());
CREATE POLICY events_allow_all ON public.events AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY events_director_insert ON public.events AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((club_id = auth_club_id()) AND (director_id = auth_director_id())));
CREATE POLICY events_director_own_club ON public.events AS PERMISSIVE FOR SELECT TO authenticated USING ((club_id = auth_club_id()));
CREATE POLICY events_director_update ON public.events AS PERMISSIVE FOR UPDATE TO authenticated USING ((club_id = auth_club_id()));
CREATE POLICY league_interested_subs_allow_all ON public.league_interested_subs AS PERMISSIVE FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY league_matches_allow_all ON public.league_matches AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY league_sub_pool_allow_all ON public.league_sub_pool AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY league_team_players_allow_all ON public.league_team_players AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY league_teams_allow_all ON public.league_teams AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY leagues_allow_all ON public.leagues AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY message_recipients_all ON public.message_recipients AS PERMISSIVE FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY messages_all ON public.messages AS PERMISSIVE FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY notifications_allow_all ON public.notifications AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY notifications_mark_read ON public.notifications AS PERMISSIVE FOR UPDATE TO authenticated USING ((director_id = auth_director_id())) WITH CHECK ((director_id = auth_director_id()));
CREATE POLICY notifications_own ON public.notifications AS PERMISSIVE FOR SELECT TO authenticated USING ((director_id = auth_director_id()));
CREATE POLICY "Allow anon read pairings" ON public.pairings AS PERMISSIVE FOR SELECT TO anon USING (true);
CREATE POLICY pairings_allow_all ON public.pairings AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY pairings_director ON public.pairings AS PERMISSIVE FOR ALL TO authenticated USING ((round_id IN ( SELECT r.id
   FROM (rounds r
     JOIN events e ON ((e.id = r.event_id)))
  WHERE (e.club_id = auth_club_id()))));
CREATE POLICY player_clubs_allow_all ON public.player_clubs AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY constraints_director_delete ON public.player_constraints AS PERMISSIVE FOR DELETE TO authenticated USING (((created_by_director_id = auth_director_id()) OR auth_is_admin()));
CREATE POLICY constraints_director_insert ON public.player_constraints AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((created_by_director_id = auth_director_id()));
CREATE POLICY constraints_read_all ON public.player_constraints AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY player_constraints_allow_all ON public.player_constraints AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY notes_director_insert ON public.player_notes AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((director_id = auth_director_id()) AND (club_id = auth_club_id())));
CREATE POLICY notes_read_all ON public.player_notes AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY player_notes_allow_all ON public.player_notes AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY player_ratings_allow_all ON public.player_ratings AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY ratings_manual_insert ON public.player_ratings AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((is_manual = true) AND (manual_by_director_id = auth_director_id())));
CREATE POLICY ratings_read_all ON public.player_ratings AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow anon read players" ON public.players AS PERMISSIVE FOR SELECT TO anon USING (true);
CREATE POLICY players_admin_write ON public.players AS PERMISSIVE FOR ALL TO authenticated USING (auth_is_admin());
CREATE POLICY players_allow_all ON public.players AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY players_read_all ON public.players AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow anon read rounds" ON public.rounds AS PERMISSIVE FOR SELECT TO anon USING (true);
CREATE POLICY rounds_allow_all ON public.rounds AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY rounds_director ON public.rounds AS PERMISSIVE FOR ALL TO authenticated USING ((event_id IN ( SELECT events.id
   FROM events
  WHERE (events.club_id = auth_club_id()))));
CREATE POLICY "Allow anon read scores" ON public.scores AS PERMISSIVE FOR SELECT TO anon USING (true);
CREATE POLICY scores_allow_all ON public.scores AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY scores_director ON public.scores AS PERMISSIVE FOR ALL TO authenticated USING ((pairing_id IN ( SELECT p.id
   FROM ((pairings p
     JOIN rounds r ON ((r.id = p.round_id)))
     JOIN events e ON ((e.id = r.event_id)))
  WHERE (e.club_id = auth_club_id()))));
CREATE POLICY "Allow anon read sitout_log" ON public.sitout_log AS PERMISSIVE FOR SELECT TO anon USING (true);
CREATE POLICY sitout_director ON public.sitout_log AS PERMISSIVE FOR ALL TO authenticated USING ((event_player_id IN ( SELECT ep.id
   FROM (event_players ep
     JOIN events e ON ((e.id = ep.event_id)))
  WHERE (e.club_id = auth_club_id()))));
CREATE POLICY sitout_log_allow_all ON public.sitout_log AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY team_players_allow_all ON public.team_players AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY team_players_director ON public.team_players AS PERMISSIVE FOR ALL TO authenticated USING ((team_id IN ( SELECT t.id
   FROM (teams t
     JOIN events e ON ((e.id = t.event_id)))
  WHERE (e.club_id = auth_club_id()))));
CREATE POLICY "Allow anon read teams" ON public.teams AS PERMISSIVE FOR SELECT TO anon USING (true);
CREATE POLICY teams_allow_all ON public.teams AS PERMISSIVE FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY teams_director ON public.teams AS PERMISSIVE FOR ALL TO authenticated USING ((event_id IN ( SELECT events.id
   FROM events
  WHERE (events.club_id = auth_club_id()))));

DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'public' AND c.relkind IN ('r','v')
             AND c.relname NOT IN ('pin_credentials','login_attempts','app_secrets') LOOP
    EXECUTE format('GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.%I TO anon, authenticated', r.relname);
  END LOOP;
END $$;

# Tennis Event Manager

Single-file vanilla JS app: `app.html` (the main app), plus standalone `tv.html` (TV/scoreboard display) and `results.html` (public results page). No build step, no framework, no package.json — just static HTML/JS served as-is.

## Deploy workflow
- Production site: https://clubeventmanager.netlify.app/ — Netlify auto-deploys from the `main` branch only (see `netlify.toml`: no build command, publishes repo root, redirects `/` to `/app.html`).
- For changes discussed and approved in chat: commit and push directly to `main`. No PR step needed (single-user project).
- For anything risky or hard to reverse (schema/migrations, auth logic, deploy config): describe the change and wait for explicit go-ahead before pushing, same as a migration.
- The user does not pull files or run terminal/deploy commands themselves — pushing to `main` is the entire deploy step; Netlify picks it up automatically.
- GitHub Pages (`mlindsayky-rgb.github.io/tennis-event-manager/app.html`) is still live in parallel as a safety net while Netlify beds in — not the deploy target, just a passive mirror of the same `main` branch. Ask before disabling it.

## Backend
- Supabase project: "Battle Tracker", ref `vrnvhrruvzcnslvceacn`.
- Anon-key-only client, no real per-role auth — PIN-based login. Admin PIN (`admin_config`), director PIN (`directors`), and team-level coach/captain PINs (`league_teams.coach_pin_hash` / `captain_pin_hash` — a coach or captain logs into one specific team, not a personal account).
- Role hierarchy: admin > director > coach > captain (> player). Role gating is UI-only (hiding nav/buttons) — RLS is enabled on tables but with permissive `allow_all` policies for `anon`/`authenticated`, so it is not a real per-role security boundary. Treat it accordingly: don't assume RLS protects anything a determined client couldn't bypass.
- "Derive, don't store" — rankings and schedules are computed live from matches/results, not cached columns.
- Core tables: `clubs`, `directors`, `players`, `coaches`, `leagues`, `league_teams`, `league_team_players`, `league_matches`, `court_results`, `league_sub_pool`, `league_interested_subs`, `messages`, `message_recipients`, `app_settings`, `admin_config`.
- `coaches` is a shared directory (name/phone/email), linked from `league_teams.coach_id` — a coach is one record, editable from the team modal or the admin/director "Coaches" tab, and edits propagate to every team that coach is linked to. Picking/typing a coach name in the team modal matches against this table before creating a new row, to avoid duplicates/typos.
- `players.home_club_id` auto-fills from a team's assigned club when a roster is loaded (bulk upload or single add) — backfill-only, never overwrites a club a player already has.
- Missing Data tooling (admin, director, and the coach-facing per-league tab — not captain) flags players missing last name / phone / home club, defaults to showing only players added in the last 45 days.
- League scheduling (`seasonWeekDates`/`isMatchWeek` in `app.html`): a league's Dates Off cause that calendar week to be skipped entirely (no match, no practice), extending the season by a week to make up the meeting count. Practice/match alternation always follows the actual, compacted meeting order — never the raw calendar date — so a skipped week never produces two of the same type in a row.
- End Date auto-fill: start date counts as week 1 day 1, so N weeks lands N×7-1 days out; each Date Off adds one bonus week. No day-of-week rounding.

## Testing
- Before shipping a schedule/roster/data-model change, write a Playwright test against a mock Supabase client (intercepts the `supabase-js` import and stubs `window.__mockDB`) and run the existing regression suite alongside it — this has repeatedly caught real bugs (date math, alternation logic, dedup) before they reached production. These test files are scratch work, not checked into this repo.
- Mock-vs-live-schema drift is a recurring bug class here: app-level JS validation can be correct while the live Postgres schema still rejects the data (a stale CHECK or NOT NULL constraint). When something "should work" but doesn't, check the live schema directly (`list_migrations`, `execute_sql`) before trusting the client-side code.

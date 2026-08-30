# Leagues Program — Requirements Overview (v2)
**Status:** Draft for internal review. Rules below reflect decisions made to date; open questions are called out separately.

---

## 1. What We're Building

A structured league program for club members. Each league is created with a **session length of either 5 weeks or 10 weeks**, chosen at the time that league is set up — since multiple leagues can run independently at once, one could be a 5-week format while another running simultaneously is 10-week. Two separate league types will run independently: **Singles** and **Doubles**. Each has its own teams, schedule, and standings — a player in one is not automatically part of the other.

---

## 2. Teams

- Each team belongs to one league (Singles or Doubles) and has three fixed attributes: a **coach**, a **home club**, and a **practice/play time slot**.
- **At league creation, the admin enters how many teams that league will have** (likely 2–4) — this sets up the league's structure from the start, similar to choosing the session length.
- **At league creation, the admin also sets a start date, an end date, and any dates off** (e.g. holidays) — this lets the schedule generator lay out the real calendar correctly around the alternating practice/play pattern, rather than just counting "week 1, week 2..." in the abstract.
- A team has **one coach at a time** — no co-coaching, to keep administration simple. If a coach needs to change, the new coach replaces the old one; we don't need to keep a record of who coached in the past, just who's currently in charge.
- A team's time slot is **locked in for the entire session** once the season starts, so the schedule can be built fairly without things shifting mid-season.
- **If a time slot becomes unavailable mid-season** (facility issue, etc.), an admin can update it — and any remaining, not-yet-played matches will automatically move to the new time. Matches already played stay as-is.

---

## 3. Match Format

**Singles:** each match, both teams field 3 players across 3 courts.
**Doubles:** each match, both teams field 4 pairs across 4 courts. Coaches choose the pairings, and pairings can change from match to match — they don't have to stay the same all season.

**Scoring within a match is the same for both leagues:**
- Standard sets are scored normally.
- Because court time is limited, a set may not finish. If that happens, whichever side has more games in that set is credited with the win for that set.
- Games are also tracked as a running total throughout the whole match and used as a tiebreaker if two sides are otherwise even.
- If a match is completely tied even after games are considered, **whichever team won Court 1 is declared the winner of the match.** This reinforces the same incentive built into the scoring system — Court 1 carries the most weight throughout, so it's a fitting, easy-to-explain tiebreaker.

---

## 4. How Matches Are Scheduled

Because teams from different clubs may have very different normal practice times, a single match is actually split across **two locations and two time slots**:

- Each team sends half its courts to one time slot, and the other half to the second time slot.
  - *Singles:* 3 courts split as sends of players to each slot.
  - *Doubles:* 4 courts split evenly, 2 courts to each slot.
- Each coach enters results only for the courts played at their own site.
- The next time the same two teams play each other, the court groupings **flip which time slot they attend** — this way, each coach gets to see and evaluate a different mix of courts/players over the course of the season, rather than only ever seeing the same two courts.
- Coaches will have the ability to fix a mistake in an entered score after the fact.

---

## 5. Substitutes and Emergency Fill-Ins

There are two very different situations, and they're treated differently:

**Substitute (normal case):** if a team is short a player, they can pull from a sub pool — either a player from another team who isn't needed by their own team that week, or a general pool of interested non-league players. A sub's results count fully — wins, sets, games — for both team standings and the sub's personal ranking, just like a regular player.

**Emergency Fill-In ("SOS"):** this is a last-resort case where no sub can be found, and a player who is already playing another court for the same team agrees to also fill the empty spot. Because the same person can't truly compete in two places at once, that specific court is automatically recorded as a loss for the team — it does **not** count as a win or add to that player's personal ranking. However, the number of games played in that court still counts toward the games tiebreaker, so the match result stays meaningful. There is no limit on how often this can be used — it's meant to be available whenever it's genuinely needed.

**Sub request notification:** when a captain/coach selects someone from the sub pool, that player should automatically receive a message with the details (e.g. "Sub requested — 7:00pm at [Club]. Reply 1 for Yes, 2 for No"), so they can confirm or decline without needing a phone call. This is a two-way communication (the app needs to receive and act on the reply, not just send a notice), which is a bit more involved than a one-way alert — worth noting as its own piece when we get to the communication provider decision.

**Self-service availability (PIN-based access):** every role gets its own PIN, and the PIN itself determines what that person can see and do — there's no separate login system, just a role-appropriate PIN:
- **Admin PIN** — full access to everything (see Section 7).
- **Coach PIN** — full access to their own team, plus full player rankings and league-wide standings, for planning purposes.
- **Captain PIN** — access to the team's roster, lineups, schedule, and score entry for their own site — but not full player rankings. Instead, shows participation stats: how many times a player marked themselves available to sub, how many times they were actually placed in the lineup, and how many times they subbed away (played, but for a different team).
- **Player PIN** — the lightest tier: mark their own sub availability, view the team's schedule, and view their own personal record. Nothing else.
- Availability marked via a Player PIN applies to **the next match only** — it doesn't carry forward as a standing flag, so it naturally resets each cycle rather than going stale.
- **Still to be decided:** at what point (if any) a player marked "available to sub" becomes visible to *other* teams' coaches/captains looking to fill a gap, versus staying visible only within their own team.

---

## 6. Player Rankings (not final, in discussion)

Separately from team standings, we're building an individual ranking system so coaches and admins can track each player's performance over time — including subs, since their results count toward this too.

- Wins and losses are scored differently depending on which court they happened on — a win on the top court is worth more than a win on a lower court, and a loss on the top court counts against a player less than a loss on a lower court. This is meant to reward strength at the top and discourage teams from stacking weaker players on lower courts to protect their record.
- Rankings are based on a player's **average performance per match played**, not their total points — so someone who's played many matches isn't automatically ranked above someone with fewer matches but a stronger record. A player needs to have played **at least 2 matches** before showing up on the official ranking board, to avoid a single result skewing the list.
- A player's score can never show below zero, to avoid a bad stretch looking discouraging on a public leaderboard.
- Coaches will also be able to see, for their own players, an estimate of how strong the opponents they've been facing are — to help decide whether a player should move up or down a court.
- A possible future idea: using these rankings to help build evenly balanced teams at the start of a new season. Not committed yet, but worth keeping in mind.

---

## 7. Visibility & Access

Access is controlled by a **PIN system** — each role (Admin, Coach, Captain, Player) has its own PIN, and the PIN itself determines what that person can see and do. There's no separate login process beyond entering the appropriate PIN.

- **Admin** (currently just one person) can see everything — full standings, full rankings, all teams.
- **Coaches** can see full team standings and full player rankings, for planning purposes.
- **Captains** can see roster, lineups, schedule, and score entry for their own site — but not full player rankings. Instead, they see participation stats: sub-availability count, actual lineup count, and how many times a player subbed away for another team.
- **Players** only ever see the **top 10** on the public ranking board, plus their own personal rank if they're outside the top 10. This is intentional — protecting morale for players who aren't near the top.
- Beyond rankings, **players can see team standings and the schedule for their own league**, and can mark their own sub availability — but nothing else (no other league's data, no full ranking board, no admin/coach/captain-level views).

---

## 8. Admin Panel & Player Directory (new, noted for later)

- The admin panel will have a top-level view for each league program (e.g. **Genesis League**, and eventually **Junior League**), each opening to a list of the leagues/seasons started under it.
- We'll maintain a **player directory** for anyone who's participated in any league: name, email, phone, and communication preferences.
- Communication preferences will likely be broken into categories rather than one blanket opt-out — for example, **Sub Alerts**, **League Updates**, and **Emergency Communications** (e.g. "club power is out, don't come to your match"). Emergency Communications may need to reach active players regardless of their other preferences, since it protects them from a wasted trip rather than being a general notice — exact rules still being worked out.
- **Sending these communications (email/text) will require a backend integration** (e.g. a transactional email/SMS service connected to the app) — not yet decided which provider, to be revisited later.

## 9. Future Consideration — Junior League (not being built yet)

- Junior League is planned for the future, format not yet finalized.
- Notably, a Junior League match could involve **singles and doubles happening simultaneously** within the same league — unlike Genesis League, where a league is always one format or the other. This means match format may eventually need to be a more flexible, per-match (or per-court) attribute rather than a fixed property of the league itself. No changes needed now — just a note to keep in mind for future architecture.

---

## 10. Member Experience Enhancements (brainstorm, not committed)

The program is being renamed simply **"Leagues"** going forward — works across adult, junior, singles, and doubles. Beyond the core mechanics already defined, these are ideas worth considering to make the experience feel like it's built *for the player*, not just a scorekeeping tool for coaches and admins:

**Before the season:**
- A simple self-serve "interest" signup for members who want to be considered for a league or the sub pool, rather than relying only on admin recruiting.
- A visible full-season calendar once a league is scheduled, so members can plan around it rather than finding out week to week.

**During the season:**
- A personal "my season" view for players — their own upcoming matches, weekly status, and record, without digging through full team standings.
- Automatic post-match summary notifications to players (e.g. their score and court), turning match data into something personal, not just administrative.
- A simple way for players to see who else is playing/subbing that week, especially useful given the two-site scheduling model.

**Recognition & retention:**
- Recognition beyond rank alone — e.g. "most improved," milestone badges (5 matches played, first win at Court 1) — since most players won't see the full leaderboard.
- An end-of-season summary for each player (their record, standout matches) that's simple to generate and the kind of thing people actually save and share.

**Reducing friction:**
- A plain-language, player-facing explanation of the scoring rules (especially the incomplete-set/tiebreak logic), so players can self-serve instead of emailing the club with questions.
- A simple way for a member to flag a scheduling conflict early, feeding into the coach's sub/status workflow.

**Communication, tied into the sub-request flow above:** when a sub is requested, and more broadly for League Updates and Emergency Communications, the goal is to make these feel like a natural part of being in the program — timely, clear, and not overly formal — rather than a bolted-on notification system.

---

## 11. Data Philosophy (guiding principle, not technical detail)

To keep the system easy to use but still powerful, the plan is to track a small number of core things — players, leagues, teams, matches, and individual court results — and calculate everything else (rankings, standings, participation stats) from that raw data rather than storing separate, duplicate numbers that could go stale or get out of sync. In practice, the single most important piece of information in the whole system is the **result of an individual court** (who played, the score, and whether it was a normal result, a substitute, or an emergency fill-in) — nearly everything else in the program (rankings, standings, tiebreakers, participation stats) is really just a different way of looking at that same information.

**Reusing existing data:** Leagues should not create its own separate player or club directory. Players and clubs already exist from Tennis Event Manager — a person's name, email, phone, and club affiliation should be entered once, ever, and simply referenced by Leagues, not duplicated. The only genuinely new, day-to-day information Leagues introduces is time-bound by nature and can't be reused from anything else: weekly availability status, sub selections, and SOS flags.

---

## 12. Design & UX Principles

- **One PIN, one obvious next screen** — whichever role's PIN is entered, land the person directly on the one thing they came to do (e.g. a captain lands on today's lineup/score entry, not a dashboard of choices).
- **Defaults over data entry** — pre-fill whatever can be reasonably assumed (like weekly status defaulting to "Playing") so people are correcting exceptions, not constructing everything from scratch.
- **Big touch targets, minimal typing** — favor taps, checkboxes, and toggles over anything that requires a keyboard, especially for coach/captain/player-facing screens used courtside.
- **Progressive disclosure** — admin and coach views can carry more detail (rankings, participation stats, multi-team schedules), but it should stay layered and accessible one tap deeper, not all flattened onto one screen.
- **Consistent screen shape across roles** — a captain's and a player's "today" screen should feel like the same app wearing different amounts of clothing, since people will move between roles over time.
- **Shared visual identity with Tennis Event Manager** — same soft color palette and component style across the product family, so Leagues doesn't need its own visual identity built from scratch.
- **Logo on the PIN entry screen and every public-facing view** (schedule, standings, admin panel) — reinforces branding and gives people confidence they're in the right place, especially since PIN-based access has no traditional login screen to anchor that trust.

---

## 13. Open Questions

1. **Typical team count range** — likely 2 to 4 per league, but not yet finalized as a hard rule (the admin will set the exact number at creation for each league).
2. **Exact scoring values** — the specific point values for court-based wins/losses (both for match scoring and player rankings) are set as a starting draft and may be adjusted once we see real season data.
3. **DNC/communication preference categories** — exact list and rules (especially how Emergency Communications interacts with opt-outs) still being defined.
4. **Communication delivery provider** — which email/SMS service to integrate for sending Sub Alerts, League Updates, and Emergency Communications — not yet decided.
5. **Two-way sub confirmation** — the sub-request notification needs to receive and act on a reply (e.g. "1 for Yes, 2 for No"), not just send a one-way alert. This is a more complex communication feature than a simple broadcast and needs its own design once a provider is chosen.
6. **Member Experience features** — none of Section 10's ideas are committed yet; worth prioritizing which (if any) make it into an early build versus later phases.
7. **Cross-team sub visibility timing** — when (if ever) does a player marked "available to sub" on their own team become visible to other teams' coaches looking for a sub, versus staying visible only within their own team? Still to be discussed.

---

## 14. Pre-Development Checklist

Before starting to build, these are the items worth a deliberate decision — even if the decision is "we'll accept the simplest version for now":

**Should be decided before writing any code:**
- [ ] Define the possible values for a court result's "type" (normal, sub, SOS) and confirm exactly what each one affects (rankings, standings, participation stats) — this one detail touches nearly every feature in the system.
- [ ] Decide the PIN format (short and memorable vs. longer and more secure) — this is hard to change once real PINs are in circulation with real members.
- [ ] Confirm whether session length (5 vs. 10 weeks) can ever change after a league is created, or if it's locked in for good once set.

**Fine to launch with a draft, as long as it's easy to adjust later:**
- [ ] Exact scoring point values — should be stored as adjustable settings, not hard-coded, so they can be tuned after seeing a real season's data.
- [ ] Communication provider choice — doesn't block the core build, but worth picking before the sub-request confirmation screen gets designed.

**Confirmed safe to defer to a later phase:**
- [ ] Member Experience ideas (Section 10)
- [ ] Junior League (Section 9)
- [ ] Cross-team sub visibility timing — can launch with the simplest rule (visible only within one's own team) and expand later.

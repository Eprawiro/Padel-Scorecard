# FLPR Phase 5.4B — Championship Ranking v1 Shadow Mode

## Purpose

Adds a second, read-only ranking model for tournament achievement and participation. It does not replace or modify FLPR Rating, the official FLPR rank, player statistics, handicap, tournaments, or ranking history.

## Deployment order

1. Run `PHASE_5_4B_CHAMPIONSHIP_RANKING_V1_SHADOW.sql` once in Supabase SQL Editor.
2. Confirm the result contains 20 players and the current first three rows are Ricky, Edy SP, and Sandy.
3. Upload the frontend files from this package to the GitHub repository root.
4. After Netlify deploys, hard refresh and open `Ranking`.

## Expected UI

- `Championship Ranking v1` appears before the existing FLPR podium.
- The panel is explicitly marked `SHADOW · NO DATABASE WRITES`.
- Official Championship Ranking contains only `ELIGIBLE` players with five or more rolling appearances.
- `EMERGING` and `PROVISIONAL` players appear inside a separate expandable watch section.
- The existing FLPR Ranking, Rating, confidence, handicap, and scorecards remain unchanged.

## Approved model

- Community scoped; Jaksel is the active flagship community.
- Rolling window: latest eight published community tournaments.
- Participation: 1 point per verified appearance.
- Finish bonuses: champion 10, runner-up 7, third 5, top 50% 3, top 70% 1.
- Field multiplier: square-root scale, capped between 0.85 and 1.35.
- Confidence: 0.55 / 0.70 / 0.82 / 0.92 / 1.00 for 1 / 2 / 3 / 4 / 5+ appearances.
- Inactivity: full 90-day grace, then 5% per 30 days, capped at 30% total decay.
- FLPR Rating is used only as a late tie-break.

## Safety

The database object is a computed `security_invoker` view with SELECT grants only. The frontend request has a safe fallback: if the view is unavailable, the existing application and FLPR Ranking continue to work.

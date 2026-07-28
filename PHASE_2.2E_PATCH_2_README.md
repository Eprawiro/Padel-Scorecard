# FLPR Premium Phase 2.2E — Patch 2

## Implemented
- Tournament lists are ordered by tournament sequence: T1, T2, T3, and onward.
- The last tournament in that sequence is labelled Latest Tournament.
- Home podium uses the latest verified tournament rather than the first returned database row.
- Player records now display Wins–Draws–Losses (W–D–L).
- Full Scoreboard includes a Draws column.
- Live momentum no longer mixes Supabase current form with snapshot clutch and adjusted win rate.
- Rating movement is labelled clearly as Rating Change.
- Scorecards distinguish Core Statistics: Live Supabase from Advanced Analytics: Snapshot Fallback.
- Mobile-facing labels and data-source wording were clarified.

## Important database limitation
The Phase 2.2C backend does not expose a dedicated tournament_date column to this frontend package. Patch 2 therefore guarantees T1 → T2 → T3 ordering by tournament sequence. A future backend migration can add tournament_date for authoritative event-date display and validation.

## Deployment
Extract and upload all files directly to the root of the GitHub repository connected to Netlify, overwrite the previous files, and commit.

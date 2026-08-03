# FLPR Phase 5.2B — Statistics Center Audit & Polish

## Scope

- Recalculate Statistics Center KPI values from the current live player pool.
- Fix the Average Win Rate double-percentage conversion (`41.5` becoming `4150%`).
- Keep Average Rating and Rating Spread synchronized with the same live player set.
- Preserve the approved Competitive Balance Index baseline until its next official model revision.
- Add an explicit Live Supabase source/evidence banner.
- Improve KPI and leaderboard layouts for mobile devices.
- Preserve all Phase 5.2A advanced metrics, relationships, rankings, ratings, handicaps, histories, predictions, achievements, and Admin behavior.

## Calculation contract

- Average Rating = sum of current player ratings / verified player profiles.
- Rating Spread = highest current rating - lowest current rating.
- Average Win Rate = sum of player win-rate percentages / verified player profiles.
- No additional percentage multiplication is applied after live Supabase normalization.
- Scheduled and unplayed matches remain excluded by the Phase 5.2A live analytics layer.

## Local regression result

- Player profiles: 20
- Average Rating: 47.73
- Rating Spread: 39.09
- Average Win Rate: 48.8%
- JavaScript syntax: passed
- Cache version: `5.2b1`

## Production validation

After deploying the flat package to GitHub `main` and waiting for Netlify:

1. Hard refresh the website with `Ctrl+Shift+R`.
2. Open `Statistics` from the main menu.
3. Confirm Average Win Rate is near 50%, never thousands of percent.
4. Confirm the Live Supabase evidence banner reports 20 verified profiles.
5. Confirm the four KPI cards use a two-column mobile layout.
6. Confirm all Phase 5.2A advanced leaderboards still load.

### Verified production result

- Live Supabase profiles: 20
- Average Rating: 51.05
- Rating Spread: 57.91
- Competitive Balance Index: 78.83
- Average Win Rate: 41.5%
- Desktop/live SQL parity: passed
- Mobile 2 x 2 KPI layout: passed
- Horizontal overflow: none observed
- Phase 5.2A advanced leaderboards: preserved

## Architecture boundary

Phase 5.2B is a zero-regression Statistics Center refinement. Multi-community isolation is reserved for Phase 5.3; Jaksel T1-T6 remains the stable flagship baseline.

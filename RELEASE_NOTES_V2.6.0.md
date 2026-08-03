# FLPR Premium v2.6.0 — Live Advanced Analytics

## Highlights

- Activated live Supabase advanced metrics for all verified player profiles.
- Added dynamic Clutch, Schedule Strength, Partner Versatility, Momentum, and Dominance calculations.
- Added small-sample protection for Clutch and Versatility.
- Added live completed-match partner and opponent relationship analytics.
- Added advanced Statistics Center leaderboards.
- Preserved official ranking, rating, handicap, and tournament-history integrity.
- Excluded scheduled and unplayed matches from analytical calculations.
- Added explicit insufficient-evidence handling instead of fabricated zero values.
- Fixed public Supabase REST access for the advanced-metrics view.
- Retained safe snapshot fallback if live Supabase loading is unavailable.

## Production validation

- 20 player profiles covered.
- 19 players initially carried verified close-match Clutch evidence; players without evidence display an explicit unavailable state.
- 20 players covered by Schedule Strength and Versatility.
- 63 completed matches and 252 completed player-match rows audited.
- 12 scheduled/unplayed matches excluded.
- 182 directed partner relationships and 210 directed opponent relationships verified.
- Edy SP verified live profile: Momentum 38.0, Consistency 95.2, Dominance 44.1, Clutch 42.1, Versatility 47.3, Schedule Strength 53.1.
- Most Dominant, Clutch Leaders, Most Versatile, and Toughest Schedule leaderboards verified in production.

## Stable checkpoint

- Recommended tag: `v2.6.0`
- Target branch: `main`
- Release status: Production verified

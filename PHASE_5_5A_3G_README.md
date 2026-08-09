# FLPR Phase 5.5A-3G — Scoped Historical Analytics

Creates community-scoped equivalents of the verified ranking timeline, career statistics, and player analytics dashboard.

## Run

1. Run `PHASE_5_5A_3G_SCOPED_HISTORICAL_ANALYTICS.sql` in Supabase SQL Editor as `postgres`.
2. Send the final audit table. Every result must be `true`.
3. Do not upload frontend files yet.

## Safety

- Existing legacy Jaksel views and all stored history remain untouched.
- Every window function and streak calculation partitions by both community and player.
- Only active communities are exposed.
- Jakarta Utara remains inactive and must return no rows.


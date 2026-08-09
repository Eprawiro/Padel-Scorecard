# FLPR Phase 5.5A-3E — Scoped Advanced Analytics

This database checkpoint creates community-partitioned partner/opponent and advanced-performance read models.

## Run

1. Open Supabase SQL Editor using role `postgres`.
2. Paste and run `PHASE_5_5A_3E_SCOPED_ADVANCED_ANALYTICS.sql` once.
3. Confirm every row in the final audit returns `true`.
4. Send the audit result before deploying any frontend follow-up.

## Safety

- No existing player, tournament, result, ranking, rating, handicap, or history row is changed.
- Jakarta Selatan must match the existing legacy analytics exactly.
- Jakarta Utara remains inactive and produces no public analytics rows.
- Do not activate Jakarta Utara yet.


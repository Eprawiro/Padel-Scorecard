# FLPR Phase 5.5A-3B — Jaksel Scoped Baseline Synchronization

Run the SQL file once in Supabase SQL Editor using role `postgres`.

The migration:

- synchronizes all 20 Jaksel community statistics rows with current validated production values;
- adds/reconciles the 60 verified Jaksel FLPR ranking-history rows;
- preserves all legacy production tables;
- preserves the 20-row T7 Championship baseline;
- leaves Jakarta Utara inactive and completely empty;
- creates no synthetic player, tournament, score, ranking, or history data.

The operation is transactional. A failed guard rolls back the entire migration.

Send the final `audit_item,result` table before continuing to Phase 5.5A-3C public read views.

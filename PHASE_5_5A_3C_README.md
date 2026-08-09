# FLPR Phase 5.5A-3C — Community-Scoped Public Read Models

Run the SQL file once in Supabase SQL Editor using role `postgres`.

This additive migration creates:

- community-scoped public player, tournament, ranking-history, rating-history, and handicap-history views;
- community-specific current handicap fields;
- Championship Ranking v2 partitioned independently by community;
- Championship event breakdown v2 partitioned independently by community.

The existing Jaksel Championship v1 views and all legacy production tables are preserved as rollback references. Jakarta Utara remains inactive, empty, and absent from every public read model.

Send the final `audit_item,result` table before deploying the frontend community switcher.

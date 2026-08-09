# FLPR Phase 5.5A-3A — Public Scope Readiness Audit

Run `PHASE_5_5A_3A_COMMUNITY_PUBLIC_SCOPE_READINESS_AUDIT.sql` in Supabase SQL Editor using the `postgres` role.

This audit is read-only. It verifies:

- Jakarta Selatan remains the protected active/default production community.
- Jakarta Utara exists but remains inactive and empty.
- The Jaksel community-scoped statistics and histories are synchronized with the current legacy production baseline.
- The Championship v1 views are still in their expected pre-migration Jaksel-only state.
- Community tables have RLS enabled.

Some synchronization checks may return `false`. That is discovery evidence, not permission to repair data manually. Send the complete result table before running the Phase 5.5A-3B migration.

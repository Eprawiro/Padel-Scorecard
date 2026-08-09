# FLPR Phase 5.5A-1A — Function Privilege Hardening

Run this patch after the Phase 5.5A-1 audit reports false for the two Superuser-only function checks.

The patch explicitly removes Supabase default function execution privileges from `anon`. Authenticated calls still pass through the internal Superuser or assigned Community Admin authorization checks.

It changes no communities, memberships, tournaments, rankings, statistics, or history rows. All eight audit results must be `true`.

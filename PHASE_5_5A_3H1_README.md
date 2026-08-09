# FLPR Phase 5.5A-3H1 — Public View Privilege Hardening

Revokes inherited non-read privileges from all 13 public/scoped views and restores only `SELECT` for `anon` and `authenticated`.

## Run

1. Run `PHASE_5_5A_3H1_PUBLIC_VIEW_PRIVILEGE_HARDENING.sql` as `postgres`.
2. Send the final audit table; all six results must be `true`.
3. After it passes, rerun Phase 5.5A-3H Final Public Isolation Audit.

## Safety

- No database rows, formulas, view definitions, or RLS policies are changed.
- Admin mutations continue through protected RPC functions, not public views.
- Jakarta Utara remains inactive.


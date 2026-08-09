# FLPR Phase 5.5A-3F — Historical Analytics Scope Readiness

This is a read-only discovery checkpoint. It does not create, update, or delete database objects or rows.

## Step 1 — Readiness audit

Run `PHASE_5_5A_3F_A_HISTORICAL_ANALYTICS_READINESS_AUDIT.sql` in Supabase SQL Editor using role `postgres`.

Send the final `audit_item,result,details` table. Every result must be `true`.

## Step 2 — View discovery

Run `PHASE_5_5A_3F_B_HISTORICAL_VIEW_DISCOVERY.sql` separately.

Export its result as CSV and send the CSV back. It contains only database view definitions and column metadata—no player credentials or secret keys.

## Safety

- Jakarta Utara stays inactive.
- No frontend deployment is included yet.
- Existing Jaksel analytics and historical views remain unchanged.


# FLPR Phase 5.5A-1 — Multi-Community Administration Foundation

This is the controlled first installation step after stable checkpoint v2.8.4.

## What it installs

- Secure community-access helper.
- Superuser-only community creation and status management.
- Superuser-only Community Admin assignment.
- Community owner/admin membership management.
- Public active-community directory with player and tournament counts.

## Safety behavior

- Creates no second community.
- Jaksel remains the only active and default community.
- Requires exactly 20 active Jaksel memberships and 7 published Jaksel tournaments.
- New communities are created as `inactive` and cannot appear publicly until explicitly activated.
- Community Admins cannot create communities or assign other Admins.
- Existing IDs, rankings, Championship history, FLPR history, tournament data, and v2.8.4 frontend are unchanged.

## Run order

1. Run `PHASE_5_5A_1_MULTI_COMMUNITY_ADMIN_FOUNDATION.sql` in Supabase SQL Editor as `postgres`.
2. Confirm that all eight audit results are `true`.
3. Do not manually create Community 2 yet.
4. Return the audit results before installing the 5.5A-2 Admin UI and public Community Switcher.

# FLPR Phase 5.5A-2 — Community Manager UI

This package adds the first production UI for FLPR multi-community administration.

## Prerequisite

Run and validate these database packages first:

1. `PHASE_5_5A_1_MULTI_COMMUNITY_ADMIN_FOUNDATION.sql`
2. `PHASE_5_5A_1A_FUNCTION_PRIVILEGE_HARDENING.sql`

The privilege audit must report all items as `true`.

## Deploy

Upload the files in this ZIP to the repository root and commit them to `main`:

- `index.html`
- `app.js`
- `flpr-admin.js`
- `styles.css`

Allow Netlify to finish deployment, then hard-refresh the production site.

## Verify as Superuser

1. Sign in to Admin.
2. Open **Communities**.
3. Confirm Jakarta Selatan is visible as `active`, `default`, and `Protected`.
4. Confirm the create-community form is visible.
5. Confirm the Community Admin assignment form is visible.

## Verify as regular Admin

1. Sign in as a regular Admin.
2. Open **Communities**.
3. Confirm the page is read-only.
4. Confirm create, activate/deactivate, and assignment controls are absent.

## Safety boundary

- A new community is always created as `inactive`.
- Do not activate a second community yet.
- Do not add synthetic players, tournaments, rankings, or history.
- Jakarta Selatan remains the only active/default production community.
- Phase 5.5A-3 will add community-scoped public datasets and the public community switcher before Community 2 activation.

## Expected result

Phase 5.5A-2 provides a safe Community Manager without changing existing Jakarta Selatan ranking, rating, handicap, Championship Ranking, history, tournament, or analytics results.

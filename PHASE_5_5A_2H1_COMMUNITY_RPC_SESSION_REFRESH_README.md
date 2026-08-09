# FLPR Phase 5.5A-2H1 — Community RPC Session Refresh

This hotfix resolves `Request failed (401)` when a long-lived Admin session calls the new Community Management RPC endpoints.

## Cause

The legacy Admin API refreshed an expired Supabase access token automatically. The new direct REST/RPC helper did not yet perform the same refresh.

## Fix

- Refresh an expired access token once after a REST/RPC `401` response.
- Retry the original request with the new token.
- Keep all database privileges and Superuser authorization checks unchanged.

## Deploy

Upload and replace:

- `index.html`
- `flpr-admin.js`

After Netlify deploys, hard-refresh, log out, and log in once before retesting **Create Inactive Community**.

The new community must remain `inactive`; do not activate it before Phase 5.5A-3 is complete.

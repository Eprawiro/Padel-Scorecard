# FLPR Phase 5.5C-5B — Superuser Publication Approval

This release adds a protected Superuser review surface for non-default community publication requests.

## Backend boundary

- The Edge Function validates the caller JWT and active Admin profile.
- List, approve, and reject actions require the `superuser` role.
- The browser never receives or uses the service-role credential.
- Approval calls `flpr_process_community_publication_request` only from the Edge Function.
- Typed confirmation is verified by both the browser and backend.
- Every decision is written to `flpr_admin_activity`.

## Deployment order

1. Deploy the updated `flpr-admin-api` Edge Function.
2. Deploy the frontend release files to the repository root.
3. Hard-refresh and sign in again.

Deployment itself creates no request and executes no publication.

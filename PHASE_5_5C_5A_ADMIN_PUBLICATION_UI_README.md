# FLPR Phase 5.5C-5A — Admin Publication UI

This release connects the verified Phase 5.5C-4 backend contracts to the existing mobile-first Admin import workflow.

## Added

- Read-only controlled-publication preflight for every verified staged tournament.
- Redacted request status and execution state.
- Owner/Admin **Request Publication** action.
- Owner/Admin **Cancel Request** action while a request is pending.
- Visible reminder that final calculation, snapshots, activation, and publication remain backend-only.

## Preserved safety boundary

- The Admin portal never calls the service-role processor or controlled publisher.
- No Approve or Publish control is rendered for ordinary Admins or the Superuser browser session.
- Jaksel continues to use its existing protected production importer.
- Inactive communities remain private until backend approval and all final readiness checks pass.

## Deployment

Upload the release files to the repository root, commit to `main`, wait for Netlify, then hard-refresh the site.

## Verification

1. Sign in to Admin and open **Import Tournament**.
2. Choose an inactive non-default community.
3. Confirm the Private Staging Inventory loads.
4. Confirm each verified staged tournament shows preflight checks and a controlled-publication card.
5. Confirm the portal shows Request/Cancel only and never shows Approve/Publish.
6. Confirm the layout stacks cleanly on a phone screen.

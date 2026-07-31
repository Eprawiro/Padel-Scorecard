# FLPR Phase 5.1B — Admin Frontend Integration

## Included

- Protected Admin login using FLPR User ID and Supabase password.
- Superuser-only create, activate, deactivate, and delete Admin users.
- Secured Americano tournament preview and transactional publish using the signed-in access token.
- Optional tournament cover and gallery photo selection during import.
- Player photo upload and replacement workflow.
- Admin activity log and live system status.
- Logout and expired-session handling.

## Production identity

- Supabase project: `gjnidgazhvswtrjnnuxk`
- Admin API: `flpr-admin-api`
- Import API: `flpr-import-engine`
- Superuser ID: `eprawiro`

Passwords and service-role credentials are never stored in the frontend.

## Deployment

1. Run `PHASE_5_1B_ADMIN_MEDIA_POLICIES.sql` once in Supabase SQL Editor.
2. Upload all frontend files from this folder to the root of `Eprawiro/Padel-Scorecard`. Netlify will deploy automatically from the connected GitHub branch.

After deployment, open `#admin`, sign in, and validate System Status before importing a tournament.

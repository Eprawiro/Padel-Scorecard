# FLPR Phase 5.1D — Production Hardening

## Included

- Player Alias mutations restricted to active Superusers through RLS.
- Active Admins retain read-only access to alias mappings.
- Non-Superuser frontend renders User Management and aliases in read-only mode.
- Superuser retains create, activate/deactivate, and delete controls.
- Frontend cache versions bumped to `5.1d`.
- Existing Phase 5.1C alias/import behavior retained.

## Verified production regression

- Official alias rows remain `Edy → Edy SP`, `Niko → Nico`, and `Sandi → Sandy`.
- Temporary CRUD test alias was created, deactivated, reactivated, and deleted.
- Trial Americano preview matched Sandi and Edy through aliases.
- Alvin remained a new player.
- Trial tournament was not published; official tournament count remained 6.

## Deployment

1. SQL hardening has already been applied in production. The included SQL is idempotent.
2. Upload all ZIP contents to the root of `eprawiro/Padel-Scorecard`.
3. Commit directly to `main` and wait for Netlify.
4. Verify Superuser Alias Manager and cache version after deployment.

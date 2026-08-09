# FLPR Premium v2.9.0 — Multi-Community Foundation

## Highlights

- Added a scalable multi-community architecture while preserving one global player identity.
- Preserved Jakarta Selatan as the active default flagship with its complete production history.
- Added Jakarta Utara as an inactive, empty community for controlled future onboarding.
- Added Superuser Community Management with safe inactive-first community creation.
- Added a public community selector that exposes active communities only.
- Added community-scoped player, tournament, ranking, rating, handicap, Championship, relationship, advanced-metric, career, dashboard, and historical timeline views.
- Preserved all Jaksel Championship calculations, analytics, player scorecards, and historical results.
- Hardened all 13 public/scoped views to `SELECT`-only access for `anon` and `authenticated` roles.
- Verified Row Level Security across all six scoped data tables.

## Production verification

- 20 Jaksel players
- 7 published Jaksel tournaments
- 60 Jaksel ranking-history rows
- 396 Jaksel relationship rows
- 20 Jaksel advanced-metric rows
- 20 Championship ranking rows and 45 event-breakdown rows
- 60 historical timeline rows, 20 career rows, and 20 dashboard rows
- Jakarta Utara remains inactive, empty, non-default, and absent from every public scoped view
- Final Public Isolation Audit: all checks passed

## Safety

- No legacy Jaksel data was removed or overwritten.
- No public write privilege remains on the 13 public/scoped views.
- Jakarta Utara must remain inactive until its independent onboarding and validation phase is complete.


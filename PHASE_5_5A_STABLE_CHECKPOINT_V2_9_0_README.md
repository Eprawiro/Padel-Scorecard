# FLPR Premium v2.9.0 — Phase 5.5A Stable Checkpoint

Production checkpoint for the multi-community foundation and public isolation release.

## Verified state

- Jakarta Selatan remains the only active/default public community.
- Jakarta Utara exists as an inactive, empty, non-default community.
- Jaksel retains 20 players, 7 published tournaments, and 60 ranking-history rows.
- Championship, advanced, relationship, and historical analytics are community-scoped.
- All 13 public/scoped views exist and expose `SELECT` only to public application roles.
- All six scoped tables have Row Level Security enabled.
- Legacy Jaksel sources remain preserved.

## GitHub deployment

Upload the extracted files to the repository root on branch `main`. Existing files with the same names are updated by the commit; GitHub does not show a separate “Replace existing files” question.

Recommended commit message:

`Deploy FLPR Phase 5.5A Multi-Community Foundation v2.9.0`

After Netlify finishes, verify the public community selector shows only Jakarta Selatan. Do not activate Jakarta Utara yet.

## Database note

The included Phase 5.5A SQL files are the installed migration and audit record. Do not rerun migration scripts unnecessarily. The final isolation audit is safe to rerun because it is read-only.


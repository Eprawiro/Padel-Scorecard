# FLPR Phase 5.5B-1H — Newcomer Community Sync Hotfix

This additive production hotfix closes the synchronization gap discovered after
Michael K was imported as the T8 champion.

- Preserves the installed `flpr_commit_tournament(jsonb)` function unchanged.
- Synchronizes the active/default community statistics after every legacy FLPR
  recalculation.
- Creates the missing scoped statistics row for future newcomers automatically.
- Keeps player photos dynamic through the live `photo_url` mapping in `app.js`.
- Does not activate or populate Jakarta Utara.

Install the SQL once. All five post-install audit rows must return `true`.

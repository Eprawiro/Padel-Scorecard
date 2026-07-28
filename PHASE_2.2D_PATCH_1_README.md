# FLPR Premium Phase 2.2D — Patch 1

## Fixes
- Tournament `Total Points` is now calculated from all rows in `tournament_players`.
- `Average Points` is calculated safely and can no longer display `NaN`.
- Missing numeric values display an em dash instead of `NaN` or `undefined`.
- The newest tournament is labelled `Latest Tournament` based on database order, not a hard-coded tournament ID.
- Podium rendering is guarded when fewer than three podium rows are available.

## Deploy
Extract the ZIP and upload all files directly to the root of the GitHub repository connected to Netlify. Commit the changes and wait for Netlify status `Published`. Then refresh the site.

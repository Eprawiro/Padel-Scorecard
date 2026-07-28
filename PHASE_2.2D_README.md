# FLPR Premium Phase 2.2D — Live Supabase Frontend Integration

## What changed
- Tournament Center loads published tournaments from Supabase.
- Ranking, handicap, player record, rank movement, and core statistics load from Supabase.
- Existing advanced workbook analytics remain as a temporary fallback where Phase 2.2C has no database columns yet.
- If Supabase is unavailable or read policies block access, the site remains usable using `flpr-data.json` and logs the live error in the browser console.

## Deployment
1. Delete the old files in the GitHub repository root, except `.git` metadata managed by GitHub.
2. Upload **all files inside this package** directly into the repository root. Do not upload the containing folder.
3. Commit the changes. Netlify will deploy automatically.
4. Open the deployed site and hard-refresh/reload it.

## Required Supabase read access
The anon role must be able to SELECT published/active rows from:
- `players`
- `player_statistics`
- `tournaments`
- `tournament_players`

The frontend never uses the service-role key. Keep the service-role key private.

## Verification
- Tournament cards should show `Published · Live Supabase`.
- Ranking and handicap should match Supabase `players` + `player_statistics`.
- After a new tournament is confirmed, refresh the website; no new frontend build should be required.

## Current hybrid limitation
Phase 2.2C does not store all workbook-derived advanced metrics (for example clutch, partner chemistry, schedule strength, and coaching text). These fields continue from the snapshot until a later database analytics migration is installed.

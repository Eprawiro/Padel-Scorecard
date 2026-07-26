# FLPR Premium V1.0 — Real Dashboard

Production static application matching the approved FLPR Premium dashboard direction.

## GitHub → Netlify
1. Put every file from this package in the repository root.
2. Connect the GitHub repository to Netlify.
3. Build command: leave blank.
4. Publish directory: `.`
5. Deploy branch: `main`.

`netlify.toml` already contains the publish and SPA redirect settings.

## Data source
`FLPR_Master_Workbook_v2.6_PhaseC_Complete.xlsx` is the official workbook source. The website reads the generated `flpr-data.json` file.

## V1.1 Player Scorecards
- Dynamic scorecard route for every player: `#player/<slug>`
- Click any player from Players or Live Ranking
- Premium performance radar, core metrics, rating intelligence, strengths/development areas, partner/opponent matrix, rating drivers, data status
- Print / Save as PDF button
- Responsive mobile layout

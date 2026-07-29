# FLPR Phase 4.2A — Official Ranking UX

## Included
- Official and Provisional ranking badges read from `ranking_eligible`.
- Established, Emerging, and Provisional player-status badges read from `player_status`.
- Official Rating reads from `official_rating`.
- Confidence display reads from `confidence_score`.
- Interactive information popups and ranking-status legend.
- Responsive desktop and mobile styling.

## Deployment
Upload all files in this ZIP to the root of the GitHub repository, replacing files when prompted. Netlify can then deploy from the repository as usual.

## Expected database columns
`official_rating`, `confidence_score`, `player_status`, `ranking_eligible` in `player_statistics`.

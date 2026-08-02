# FLPR Phase 5.2B-1 — Statistics Center Premium

## Included
- Dedicated Advanced Metrics Leaders area for Momentum, Consistency, Dominance, Clutch, Versatility, and Schedule Strength.
- Complete 20-player Advanced Metrics Matrix linked to every Player Scorecard.
- Metric interpretation tiers: Elite, Excellent, Good, Average, Developing, and Insufficient Evidence.
- Mobile-first cards and horizontally scrollable comparison matrix.
- Existing live Supabase metrics, ranking, scorecards, relationships, predictions, admin, and import flows retained.
- No database schema changes in this patch.

## Jaksel safety rule
This patch is frontend-only. It does not modify tournaments, matches, players, ranking, rating, handicap, aliases, or production SQL objects.

## Deployment
1. Upload all ZIP contents to the root of `Eprawiro/Padel-Scorecard` and replace existing files.
2. Commit to `main` and wait for Netlify.
3. Perform a hard refresh or open the site in an Incognito tab.
4. Open **Statistics** from the main menu.

## Validation
- Advanced Metrics Leaders shows six cards.
- Advanced Metrics Matrix shows 20 players.
- Every row opens the correct Player Scorecard.
- Clutch may show `— / Insufficient` only where verified evidence is unavailable.
- On mobile, cards fit the screen and only the matrix scrolls horizontally.
- Ranking, Tournament Center, Player Scorecards, Pairing & Rivalries, Predictions, and Admin remain available.

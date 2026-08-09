# FLPR Phase 5.5A-3G1 — Frontend Historical Analytics Cutover

Moves scorecard ranking timeline, career statistics, streaks, volatility, and historical analytics dashboard to the validated community-scoped views.

## Deploy

Upload and replace these files in the GitHub repository root:

- `index.html`
- `flpr-supabase.js`

Wait for Netlify and perform a hard refresh.

## Verify

1. Public selector still contains only Jakarta Selatan.
2. Open Edy SP, Sandy, and another player scorecard.
3. Confirm Historical Analytics Engine, ranking history, rating change, career position, and historical charts remain populated.
4. Confirm Statistics, Pairing & Rivalries, and Championship Ranking remain unchanged.
5. Confirm mobile layout remains stable.

## Safety

- Jakarta Utara remains inactive and absent from the public selector.
- No database write or schema change is included in this frontend package.
- No legacy cross-community fallback is used for historical analytics.


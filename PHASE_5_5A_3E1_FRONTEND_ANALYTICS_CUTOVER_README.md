# FLPR Phase 5.5A-3E1 — Frontend Analytics Cutover

Moves public partner/opponent and advanced-performance loading from the legacy global views to the validated community-scoped views installed in Phase 5.5A-3E.

## Deployment

Upload these files to the GitHub repository root and replace the existing files:

- `index.html`
- `flpr-supabase.js`

Wait for Netlify deployment and perform a hard refresh.

## Verification

1. Community selector still shows only **Jakarta Selatan**.
2. Jakarta Utara remains inactive and absent from the public selector.
3. Open **Statistics** and confirm Advanced Metrics remain populated.
4. Open **Pairing & Rivalries** and confirm partner/opponent data remain unchanged.
5. Open several player scorecards and confirm Advanced Performance Profile and Partner & Opponent Matrix remain populated.
6. Confirm mobile layout remains stable.

## Safety boundary

- Do not activate Jakarta Utara yet.
- No database mutation is included in this package.
- Historical career analytics remain restricted to the default community until their scoped replacement is validated.


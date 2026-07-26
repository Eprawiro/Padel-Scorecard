# FLPR Premium v1.0 — Technical Documentation

## Architecture
Static single-page application using native HTML, CSS, and JavaScript. Routing is hash-based. There is no framework, package manager, build step, or server-side runtime.

## Data layers
- `flpr-data.json`: validated workbook-derived rankings, metrics, awards, and relationship analytics.
- `TOURNAMENTS` in `app.js`: packaged verified tournament archive and pending historical slots.
- Browser local storage key `flpr_verified_tournaments_v1`: administrator-approved local tournament snapshots.

## Integrity principles
The application does not generate historical standings that are absent from source data. Historical comparisons and player timelines display only packaged or locally imported verified tournaments.

## Momentum
`0.55 × Recent Form + 0.25 × Clutch + 0.20 × Adjusted Win Rate`, clamped to 0–100.

## Photo mapping
The `PHOTO` object maps normalized player names to flat image filenames. The fallback is `generic-padel-avatar.svg`.

## Error handling
Page rendering is wrapped in a visible error boundary. Data fetch failure and page-render failure do not produce a silent blank page.

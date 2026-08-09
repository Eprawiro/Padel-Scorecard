# FLPR Phase 5.5A-3D — Public Community Switcher

## Purpose

Adds the active-community selector and scopes the public core loader to the selected community.

## Deployment

Upload these files to the GitHub repository root, replacing the existing files with the same names:

- `index.html`
- `app.js`
- `flpr-supabase.js`
- `styles.css`

After Netlify finishes deploying, hard-refresh the production site.

## Production verification

1. The header shows **Jakarta Selatan** as the selected community.
2. The selector contains only active public communities.
3. **Jakarta Utara must not appear** while it remains inactive.
4. Jaksel player, tournament, ranking-history, Championship Ranking, and Championship breakdown data remain unchanged.
5. Mobile header, logo, selector, and menu remain usable without overlap.

## Safety boundary

- Do not activate Jakarta Utara in this phase.
- Core public data and Championship views are community-scoped.
- Legacy advanced relationship analytics are permitted only for the default Jaksel community until their scoped replacements are deployed.
- The tournament import/publish workflow is not yet opened for a second community.


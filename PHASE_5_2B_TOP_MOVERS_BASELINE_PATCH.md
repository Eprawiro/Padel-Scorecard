# FLPR v2.6.2 — Top Movers Baseline Presentation Patch

## Problem

The Statistics Center displayed five player names under Top Movers even though every official rank movement value was zero. The dash values were technically correct, but the ranked list implied that those players had moved.

## Resolution

- Filter Top Movers to players with a non-zero official snapshot movement.
- When no movement exists, display a transparent baseline state instead of an arbitrary ranked list.
- Automatically restore the player leaderboard after a future verified tournament creates non-zero official snapshot movement.
- No database, ranking, rating, handicap, history, or analytics calculation is changed.

## Empty-state message

`No official ranking movement yet`

`Top Movers will activate after the next verified tournament creates a new official ranking snapshot.`

## Cache

- CSS: `5.2b2`
- Application JavaScript: `5.2b2`

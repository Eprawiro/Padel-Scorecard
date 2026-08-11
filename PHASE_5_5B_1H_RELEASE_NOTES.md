# FLPR Phase 5.5B-1H — Michael K Newcomer Fix

## Production issue resolved

Michael K was imported correctly as the T8 champion with 24 points, but the
community-scoped statistics mirror was not created. This produced null public
statistics that the frontend displayed as rank/rating zero. His uploaded photo
also did not appear on podium cards because those cards used only the legacy
static photo map.

## Fixes

- Repaired and verified all 21 Jakarta Selatan community-statistics rows.
- Preserved Michael and Michael K as separate global player identities.
- Preserved Michael K as provisional: rank 4, 1 tournament, 6 matches, official
  rating 65.3807, handicap -2.46.
- Added an additive default-community synchronization trigger for future legacy
  ranking recalculations and newcomer imports.
- Preserved the installed production `flpr_commit_tournament(jsonb)` function.
- Updated avatar resolution to prefer each player's live Supabase `photo_url`,
  with the existing static map and generic avatar as fallbacks.

## Verified installation audit

All five database checks returned `true`: commit function preserved, scoped
statistics complete, Michael K live/provisional, sync function installed, and
sync trigger enabled.

## Next checkpoint

Continue FLPR Phase 5.5B-2M after GitHub/Netlify deployment verification.

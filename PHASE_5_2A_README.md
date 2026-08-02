# FLPR Phase 5.2A — Live Supabase Analytics

## Included

- Advanced player statistics read live from `player_statistics` for all 20 players.
- Live partner and opponent relationships calculated from completed matches only.
- Scheduled/unplayed matches are excluded.
- Live dashboard tier from `v_flpr_player_analytics_dashboard`.
- Rule-based player summary, coaching priority, and reliability note use verified live metrics.
- Rating and handicap history loaders are ready for future official changes.
- Synthetic rating, ranking, and handicap profile points are removed.
- Cache versions bumped to `5.2a`.

## Verified backend coverage

- 20/20 advanced-statistic player coverage.
- 63 completed matches and 252 completed player-match rows.
- 182 directed partner relationships covering 20 players.
- 210 directed opponent relationships covering 20 players.
- 12 scheduled/unplayed matches are excluded.
- Rating and handicap history currently contain no rows; the UI displays verified current values without inventing history.

## Deployment

1. Run `PHASE_5_2A_LIVE_RELATIONSHIP_VIEW.sql` in Supabase SQL Editor.
2. Upload all ZIP contents to the root of `eprawiro/Padel-Scorecard`.
3. Commit to `main` and wait for Netlify.
4. Validate Statistics Center, Pairing & Rivalries, and Edy SP Player Scorecard.

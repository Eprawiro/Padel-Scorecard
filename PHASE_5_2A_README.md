# FLPR Phase 5.2A — Live Supabase Analytics

## Included

- Core player statistics are read live from `player_statistics` for all 20 players.
- Advanced metrics are calculated dynamically by `v_flpr_advanced_metrics_live` from verified completed matches.
- Clutch uses close matches with a neutral four-match prior; players without close-match evidence display `—`.
- Schedule strength uses the average Official Rating of actual opponents.
- Versatility combines performance across partners (60%) and partner diversity (40%), with an eight-match neutral prior.
- Momentum and dominance are normalized to a consistent 0–100 presentation index.
- Live partner and opponent relationships calculated from completed matches only.
- Scheduled/unplayed matches are excluded.
- Live dashboard tier from `v_flpr_player_analytics_dashboard`.
- Rule-based player summary, coaching priority, and reliability note use verified live metrics.
- Rating and handicap history loaders are ready for future official changes.
- Synthetic rating, ranking, and handicap profile points are removed.
- Cache versions bumped to `5.2a3`.
- Achievement badges are deduplicated when the same badge is present in both live rules and the award snapshot.
- History panels clearly distinguish overall FLPR ranking snapshots from individual tournament finishing positions.

## Verified backend coverage

- 20/20 advanced-statistic player coverage.
- 19/20 players have verified close-match evidence; one correctly remains unscored for Clutch.
- 20/20 players have schedule-strength and versatility coverage.
- 63 completed matches and 252 completed player-match rows.
- 182 directed partner relationships covering 20 players.
- 210 directed opponent relationships covering 20 players.
- 12 scheduled/unplayed matches are excluded.
- Rating and handicap history currently contain no rows; the UI displays verified current values without inventing history.

## Deployment

1. Run `PHASE_5_2A_LIVE_RELATIONSHIP_VIEW.sql` in Supabase SQL Editor.
2. Run `PHASE_5_2A_ADVANCED_METRIC_PREVIEW.sql` and validate the preview.
3. Run `PHASE_5_2A_ACTIVATE_LIVE_ADVANCED_METRICS.sql`; expected coverage is `20 / 19 / 20 / 20`.
   - Existing installations that used the original `security_invoker` projection should also run `PHASE_5_2A_REST_PERMISSION_HOTFIX.sql`.
4. Upload all ZIP contents to the root of `Eprawiro/Padel-Scorecard`.
5. Commit to `main` and wait for Netlify.
6. Validate Statistics Center, Pairing & Rivalries, and Edy SP Player Scorecard.

## Production verification

- Supabase SQL validation passed.
- Public REST access passed after the permission hotfix.
- Edy SP live metrics verified: Momentum 38.0, Consistency 95.2, Dominance 44.1, Clutch 42.1, Versatility 47.3, Schedule Strength 53.1.
- Advanced leaderboards verified: Most Dominant, Clutch Leaders, Most Versatile, and Toughest Schedule.

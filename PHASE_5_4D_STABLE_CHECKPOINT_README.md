# FLPR Premium v2.8.3 — Atomic Championship History

Phase 5.4D establishes production-safe Championship Ranking v1 history without
changing the public FLPR Rating, Official Ranking, Handicap, or frontend UI.

## Production state

- Dedicated `flpr_championship_ranking_history` table with RLS.
- T7 stored as the first real Championship baseline: 20 players.
- Restricted, idempotent Championship capture function.
- Capture integrated into `flpr_commit_tournament(jsonb)`.
- Participant membership is created/activated inside the same transaction.
- Existing FLPR ranking snapshot remains in the transaction.
- No Championship table trigger exists.
- Any capture failure rolls back the complete verified tournament publish.

## Verified audit

All eight final controls passed:

1. Atomic Championship capture installed.
2. Community membership is transactional.
3. Existing FLPR snapshot is preserved.
4. FLPR history contains 60 valid rows across three complete snapshots.
5. Every FLPR snapshot contains 20 player rows.
6. T7 Championship baseline contains 20 rows.
7. No Championship trigger is enabled.
8. Tournament commit remains restricted to `service_role`.

## Activation behavior

Installation creates no additional snapshot. The second Championship snapshot
will be captured automatically only when T8 is successfully confirmed and
published. T8 will then produce genuine `previous_rank`, `rank_movement`,
`previous_score`, and `score_change` values using T7 as the baseline.

## Deployment files

- `PHASE_5_4D_CHAMPIONSHIP_HISTORY_TABLE.sql`
- `PHASE_5_4D_MANUAL_SNAPSHOT_FUNCTION.sql`
- `PHASE_5_4D_T7_BASELINE_CAPTURE.sql`
- `PHASE_5_4D_ATOMIC_CHAMPIONSHIP_CAPTURE.sql`
- `PHASE_5_4D_FINAL_POST_INSTALL_AUDIT.sql`

These migrations have already been applied to production. They are committed
to GitHub as the durable database checkpoint and should not be rerun during a
normal Netlify deployment.


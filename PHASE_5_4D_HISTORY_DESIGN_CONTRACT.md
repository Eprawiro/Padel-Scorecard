# FLPR Phase 5.4D — Championship History Design Contract

## Non-negotiable boundaries

- Championship history is separate from `flpr_community_ranking_history`, which remains the historical store for the existing FLPR Rating/Ranking model.
- Every snapshot is scoped by `community_id` and linked to one published tournament.
- Snapshots are created only after a verified tournament publish succeeds.
- Re-running publication or snapshot capture for the same community and tournament must be idempotent.
- No synthetic historical score, rank, or movement is fabricated.
- No backfill is enabled until historical calculation semantics are explicitly approved.
- Championship Ranking remains shadow/read-only in the public UI.

## Proposed dedicated snapshot identity

One row per:

`community_id + tournament_id + player_id + calculation_version`

This key prevents duplicate snapshots while allowing a future, explicitly versioned recalculation model.

## Proposed captured fields

- Community, tournament, player, and calculation version.
- Snapshot rank and previous rank.
- Rank movement.
- Championship score and previous score.
- Score change.
- Eligibility and rolling appearances.
- Raw rolling points, confidence factor, and inactivity factor.
- Championships, podiums, best finish, latest event date, and capture timestamp.

## Write boundary

The future capture function must run inside the same successful transaction as verified tournament publication. A failed tournament publish must create no Championship snapshot. A failed snapshot must roll back the entire publish transaction unless the Superuser explicitly approves a different reliability policy.

## Backfill boundary

Current Championship Ranking uses a rolling eight-tournament window. Reconstructing historical snapshots requires recalculating the model as of each tournament date using only information available at that point. Copying today’s score backward is prohibited.

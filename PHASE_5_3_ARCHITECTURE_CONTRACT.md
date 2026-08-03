# FLPR Phase 5.3 — Multi-Community Architecture Contract

## Non-negotiable requirements

- Jaksel T1-T6 remains complete, identical, and operational throughout migration.
- One global player identity may belong to multiple communities.
- Each community owns independent tournaments, ranking, rating, handicap, statistics, history, predictions, achievements, and relationship analytics.
- Edy SP remains the single platform Superuser with authority across communities.
- Community Admins may operate only their assigned communities and cannot create other Admins.
- Player aliases remain attached to the global player identity, with future community-specific override support only if evidence requires it.
- No destructive table replacement and no bulk rewrite before baseline comparison passes.

## Target entity separation

1. `players`: global human identity.
2. `flpr_communities`: community identity and configuration.
3. `flpr_community_memberships`: player membership and community-local status.
4. `flpr_community_player_statistics`: ranking, rating, handicap, and analytics per player per community.
5. `tournaments.community_id`: tournament ownership.
6. Community-aware history and relationship records.
7. Community-scoped Admin assignments and RLS.

## Compatibility strategy

- Create Jaksel as the default flagship community.
- Backfill every existing tournament and statistic into Jaksel scope without changing existing IDs.
- Maintain compatibility views so the current frontend continues to work during migration.
- Move the frontend and import engine to explicit community selection only after database parity is proven.
- Verify every pre-migration count and every Jaksel KPI before enabling another community.

## Phase gates

- 5.3A: schema audit and baseline capture.
- 5.3B: additive community schema preview.
- 5.3C: Jaksel backfill with compatibility layer.
- 5.3D: community-aware security and Admin foundation.
- 5.3E: frontend community context and zero-regression validation.

## Locked Jaksel baseline (3 August 2026)

- Global/active players: 20 / 20
- Published tournaments: 6
- Tournament participations: 41
- Matches/completed matches: 75 / 63
- Match-player/completed player-match rows: 300 / 252
- Player statistics: 20
- Ranking history: 40
- Rating history: 0
- Handicap history: 0
- Active aliases: 3
- Admin users: 1

Every post-migration Jaksel validation must reconcile to these values before another community is enabled.

# FLPR Phase 3.4A.2 — Tournament Finish Integrity Fix

## Fixed
- Championships, Runner-up, Third Place, Total Podiums, Average Finish, Best Finish, Worst Finish, Tournament count, and Top 3 Rate now use verified `tournament_players.final_position` records.
- Player matching uses immutable `player_id` instead of relying only on display-name slugs.
- Achievement badges and AI Coach championship/podium logic use the same verified finish history.
- Historical ranking snapshots remain separate from tournament finishing positions.

## Validation rule
For each player:
- Championships = count(final_position = 1)
- Runner-up = count(final_position = 2)
- Third Place = count(final_position = 3)
- Total Podiums = count(final_position between 1 and 3)
- Top 3 Rate = Total Podiums / Tournament Appearances × 100
- Average/Best/Worst Finish use all valid final positions.

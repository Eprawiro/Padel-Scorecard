-- FLPR Phase 5.3A — Audit 1: current production columns
-- READ ONLY. This query does not change production data.

select
  c.table_name,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in (
    'players',
    'tournaments',
    'tournament_players',
    'matches',
    'match_players',
    'player_statistics',
    'ranking_history',
    'rating_history',
    'handicap_history',
    'flpr_admin_users',
    'flpr_player_aliases'
  )
order by c.table_name, c.ordinal_position;

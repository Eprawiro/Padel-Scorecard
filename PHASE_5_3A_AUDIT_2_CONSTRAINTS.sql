-- FLPR Phase 5.3A — Audit 2: keys, foreign keys, and uniqueness
-- READ ONLY. This query does not change production data.

select
  tc.table_name,
  tc.constraint_type,
  tc.constraint_name,
  string_agg(kcu.column_name, ', ' order by kcu.ordinal_position) as columns,
  ccu.table_name as referenced_table,
  ccu.column_name as referenced_column
from information_schema.table_constraints tc
left join information_schema.key_column_usage kcu
  on kcu.constraint_schema = tc.constraint_schema
 and kcu.constraint_name = tc.constraint_name
left join information_schema.constraint_column_usage ccu
  on ccu.constraint_schema = tc.constraint_schema
 and ccu.constraint_name = tc.constraint_name
where tc.table_schema = 'public'
  and tc.table_name in (
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
group by
  tc.table_name,
  tc.constraint_type,
  tc.constraint_name,
  ccu.table_name,
  ccu.column_name
order by tc.table_name, tc.constraint_type, tc.constraint_name;

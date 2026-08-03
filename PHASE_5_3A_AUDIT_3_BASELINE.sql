-- FLPR Phase 5.3A — Audit 3: immutable Jaksel baseline
-- READ ONLY. Save this result before any multi-community migration.

select 'players' as audit_item, count(*)::text as result from public.players
union all
select 'active_players', count(*)::text from public.players where status = 'active'
union all
select 'published_tournaments', count(*)::text from public.tournaments where status = 'published'
union all
select 'tournament_players', count(*)::text from public.tournament_players
union all
select 'matches', count(*)::text from public.matches
union all
select 'completed_matches', count(*)::text from public.matches where status = 'completed'
union all
select 'match_players', count(*)::text from public.match_players
union all
select 'player_statistics', count(*)::text from public.player_statistics
union all
select 'ranking_history', count(*)::text from public.ranking_history
union all
select 'rating_history', count(*)::text from public.rating_history
union all
select 'handicap_history', count(*)::text from public.handicap_history
union all
select 'admin_users', count(*)::text from public.flpr_admin_users
union all
select 'active_aliases', count(*)::text from public.flpr_player_aliases where is_active
union all
select 'completed_player_match_rows', count(*)::text
from public.match_players mp
join public.matches m on m.id = mp.match_id
where m.status = 'completed'
order by audit_item;

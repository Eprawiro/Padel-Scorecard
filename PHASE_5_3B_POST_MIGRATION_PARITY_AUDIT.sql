-- FLPR Phase 5.3B — Post-migration Jaksel parity and REST audit
-- READ ONLY. No production data is changed.

with
jaksel as (
  select '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid as community_id
),
statistics_mismatch as (
  select count(*)::bigint as n
  from public.player_statistics legacy
  full join public.flpr_community_player_statistics scoped
    on scoped.player_id = legacy.player_id
   and scoped.community_id = (select community_id from jaksel)
  where legacy.player_id is null
     or scoped.player_id is null
     or (to_jsonb(scoped) - 'community_id') is distinct from to_jsonb(legacy)
),
ranking_mismatch as (
  select count(*)::bigint as n
  from public.ranking_history legacy
  full join public.flpr_community_ranking_history scoped
    on scoped.legacy_ranking_history_id = legacy.id
   and scoped.community_id = (select community_id from jaksel)
  where legacy.id is null
     or scoped.id is null
     or scoped.snapshot_key is distinct from legacy.snapshot_key
     or scoped.tournament_id is distinct from legacy.tournament_id
     or scoped.player_id is distinct from legacy.player_id
     or scoped.rank is distinct from legacy.rank
     or scoped.previous_rank is distinct from legacy.previous_rank
     or scoped.official_rating is distinct from legacy.official_rating
     or scoped.matches_played is distinct from legacy.matches_played
     or scoped.win_rate is distinct from legacy.win_rate
     or scoped.captured_at is distinct from legacy.captured_at
),
tournament_mismatch as (
  select count(*)::bigint as n
  from public.tournaments
  where community_id is distinct from (select community_id from jaksel)
),
membership_orphans as (
  select count(*)::bigint as n
  from public.flpr_community_memberships m
  left join public.players p on p.id = m.player_id
  where m.community_id = (select community_id from jaksel)
    and p.id is null
)
select 'statistics_content_mismatches' as audit_item, n::text as result from statistics_mismatch
union all
select 'ranking_content_mismatches', n::text from ranking_mismatch
union all
select 'tournament_scope_mismatches', n::text from tournament_mismatch
union all
select 'membership_orphans', n::text from membership_orphans
union all
select 'anon_reads_communities', has_table_privilege('anon', 'public.flpr_communities', 'select')::text
union all
select 'anon_reads_memberships', has_table_privilege('anon', 'public.flpr_community_memberships', 'select')::text
union all
select 'anon_reads_statistics', has_table_privilege('anon', 'public.flpr_community_player_statistics', 'select')::text
union all
select 'anon_reads_ranking_history', has_table_privilege('anon', 'public.flpr_community_ranking_history', 'select')::text
union all
select 'authenticated_reads_communities', has_table_privilege('authenticated', 'public.flpr_communities', 'select')::text
union all
select 'authenticated_reads_statistics', has_table_privilege('authenticated', 'public.flpr_community_player_statistics', 'select')::text
order by audit_item;

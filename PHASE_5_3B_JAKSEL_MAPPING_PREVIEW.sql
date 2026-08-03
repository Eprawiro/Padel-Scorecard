-- FLPR Phase 5.3B — Jaksel community mapping preview
-- STRICTLY READ ONLY: no table, column, policy, function, or data is changed.

with
jaksel as (
  select
    '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid as community_id,
    'JAKSEL'::text as community_code,
    'Jakarta Selatan'::text as community_name
),
proposed_memberships as (
  select
    j.community_id,
    p.id as player_id,
    p.status as global_status,
    case when p.status = 'active' then 'active' else 'inactive' end as membership_status
  from public.players p
  cross join jaksel j
  where p.status <> 'merged'
),
proposed_statistics as (
  select
    j.community_id,
    ps.player_id,
    ps.rank,
    ps.official_rating,
    p.handicap,
    ps.matches_played
  from public.player_statistics ps
  join public.players p on p.id = ps.player_id
  cross join jaksel j
),
proposed_tournaments as (
  select
    j.community_id,
    t.id as tournament_id,
    t.status
  from public.tournaments t
  cross join jaksel j
),
proposed_ranking_history as (
  select
    j.community_id,
    rh.id as legacy_ranking_history_id,
    rh.snapshot_key,
    rh.player_id
  from public.ranking_history rh
  cross join jaksel j
),
integrity as (
  select 'community_rows'::text as audit_item, 1::bigint as result
  union all
  select 'proposed_memberships', count(*) from proposed_memberships
  union all
  select 'proposed_statistics', count(*) from proposed_statistics
  union all
  select 'proposed_tournaments', count(*) from proposed_tournaments
  union all
  select 'proposed_published_tournaments', count(*) from proposed_tournaments where status = 'published'
  union all
  select 'proposed_ranking_history', count(*) from proposed_ranking_history
  union all
  select 'orphan_player_statistics', count(*)
  from public.player_statistics ps
  left join public.players p on p.id = ps.player_id
  where p.id is null
  union all
  select 'unresolved_tournament_players', count(*)
  from public.tournament_players
  where player_id is null
  union all
  select 'duplicate_memberships', count(*)
  from (
    select community_id, player_id
    from proposed_memberships
    group by community_id, player_id
    having count(*) > 1
  ) d
  union all
  select 'duplicate_community_statistics', count(*)
  from (
    select community_id, player_id
    from proposed_statistics
    group by community_id, player_id
    having count(*) > 1
  ) d
  union all
  select 'duplicate_community_snapshots', count(*)
  from (
    select community_id, snapshot_key, player_id
    from proposed_ranking_history
    group by community_id, snapshot_key, player_id
    having count(*) > 1
  ) d
)
select audit_item, result
from integrity
order by audit_item;

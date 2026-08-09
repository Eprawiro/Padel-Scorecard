-- FLPR Phase 5.5A-3B
-- Jaksel community-scoped baseline synchronization
-- Copies the current validated legacy production state into its community-scoped
-- mirrors. Legacy production tables are read, never changed. Jakut remains empty.

begin;

do $$
declare
  v_jaksel uuid;
  v_jakut uuid;
begin
  select id into v_jaksel
  from public.flpr_communities
  where slug='jaksel' and status='active' and is_default;

  select id into v_jakut
  from public.flpr_communities
  where slug='jakut' and status='inactive' and not is_default;

  if v_jaksel is null then
    raise exception 'Jaksel active/default baseline is missing';
  end if;
  if v_jakut is null then
    raise exception 'Jakut inactive baseline is missing';
  end if;
  if (select count(*) from public.player_statistics) <> 20 then
    raise exception 'Legacy statistics guard failed: expected 20 rows';
  end if;
  if (select count(*) from public.ranking_history) <> 60 then
    raise exception 'Legacy ranking-history guard failed: expected 60 rows';
  end if;
  if (select count(*) from public.tournaments
      where community_id=v_jaksel and status='published') <> 7 then
    raise exception 'Jaksel tournament guard failed: expected 7 published tournaments';
  end if;
  if exists(select 1 from public.flpr_community_memberships where community_id=v_jakut)
     or exists(select 1 from public.flpr_community_player_statistics where community_id=v_jakut)
     or exists(select 1 from public.tournaments where community_id=v_jakut)
     or exists(select 1 from public.flpr_community_ranking_history where community_id=v_jakut)
     or exists(select 1 from public.flpr_championship_ranking_history where community_id=v_jakut) then
    raise exception 'Jakut must remain empty before public-scope activation';
  end if;
end
$$;

-- Synchronize the current Jaksel competitive profile mirror.
insert into public.flpr_community_player_statistics (
  community_id,player_id,rank,previous_rank,tournaments_played,matches_played,
  wins,draws,losses,win_rate,total_points_for,total_points_against,
  point_difference,average_points,momentum,consistency,dominance,clutch_score,
  versatility,schedule_strength,championships,podiums,updated_at,
  adjusted_win_rate,reliability,raw_composite,official_rating,rating_status,
  confidence_score,player_status,ranking_eligible
)
select
  community.id,legacy.player_id,legacy.rank,legacy.previous_rank,
  legacy.tournaments_played,legacy.matches_played,legacy.wins,legacy.draws,
  legacy.losses,legacy.win_rate,legacy.total_points_for,
  legacy.total_points_against,legacy.point_difference,legacy.average_points,
  legacy.momentum,legacy.consistency,legacy.dominance,legacy.clutch_score,
  legacy.versatility,legacy.schedule_strength,legacy.championships,
  legacy.podiums,legacy.updated_at,legacy.adjusted_win_rate,legacy.reliability,
  legacy.raw_composite,legacy.official_rating,legacy.rating_status,
  legacy.confidence_score,legacy.player_status,legacy.ranking_eligible
from public.player_statistics legacy
cross join lateral (
  select id from public.flpr_communities where slug='jaksel'
) community
join public.flpr_community_memberships membership
  on membership.community_id=community.id
 and membership.player_id=legacy.player_id
on conflict (community_id,player_id) do update set
  rank=excluded.rank,
  previous_rank=excluded.previous_rank,
  tournaments_played=excluded.tournaments_played,
  matches_played=excluded.matches_played,
  wins=excluded.wins,
  draws=excluded.draws,
  losses=excluded.losses,
  win_rate=excluded.win_rate,
  total_points_for=excluded.total_points_for,
  total_points_against=excluded.total_points_against,
  point_difference=excluded.point_difference,
  average_points=excluded.average_points,
  momentum=excluded.momentum,
  consistency=excluded.consistency,
  dominance=excluded.dominance,
  clutch_score=excluded.clutch_score,
  versatility=excluded.versatility,
  schedule_strength=excluded.schedule_strength,
  championships=excluded.championships,
  podiums=excluded.podiums,
  updated_at=excluded.updated_at,
  adjusted_win_rate=excluded.adjusted_win_rate,
  reliability=excluded.reliability,
  raw_composite=excluded.raw_composite,
  official_rating=excluded.official_rating,
  rating_status=excluded.rating_status,
  confidence_score=excluded.confidence_score,
  player_status=excluded.player_status,
  ranking_eligible=excluded.ranking_eligible;

-- Add the missing verified Jaksel FLPR snapshot and reconcile existing mirrors.
insert into public.flpr_community_ranking_history (
  community_id,legacy_ranking_history_id,snapshot_key,tournament_id,player_id,
  rank,previous_rank,rank_movement,official_rating,adjusted_win_rate,
  reliability,raw_composite,rating_status,tournaments_played,matches_played,
  wins,draws,losses,win_rate,total_points_for,total_points_against,
  point_difference,average_points,momentum,consistency,dominance,clutch_score,
  versatility,schedule_strength,championships,podiums,snapshot_source,captured_at
)
select
  community.id,legacy.id,legacy.snapshot_key,legacy.tournament_id,legacy.player_id,
  legacy.rank,legacy.previous_rank,legacy.rank_movement,legacy.official_rating,
  legacy.adjusted_win_rate,legacy.reliability,legacy.raw_composite,
  legacy.rating_status,legacy.tournaments_played,legacy.matches_played,
  legacy.wins,legacy.draws,legacy.losses,legacy.win_rate,
  legacy.total_points_for,legacy.total_points_against,legacy.point_difference,
  legacy.average_points,legacy.momentum,legacy.consistency,legacy.dominance,
  legacy.clutch_score,legacy.versatility,legacy.schedule_strength,
  legacy.championships,legacy.podiums,legacy.snapshot_source,legacy.captured_at
from public.ranking_history legacy
cross join lateral (
  select id from public.flpr_communities where slug='jaksel'
) community
join public.flpr_community_memberships membership
  on membership.community_id=community.id
 and membership.player_id=legacy.player_id
on conflict (community_id,snapshot_key,player_id) do update set
  legacy_ranking_history_id=excluded.legacy_ranking_history_id,
  tournament_id=excluded.tournament_id,
  rank=excluded.rank,
  previous_rank=excluded.previous_rank,
  rank_movement=excluded.rank_movement,
  official_rating=excluded.official_rating,
  adjusted_win_rate=excluded.adjusted_win_rate,
  reliability=excluded.reliability,
  raw_composite=excluded.raw_composite,
  rating_status=excluded.rating_status,
  tournaments_played=excluded.tournaments_played,
  matches_played=excluded.matches_played,
  wins=excluded.wins,
  draws=excluded.draws,
  losses=excluded.losses,
  win_rate=excluded.win_rate,
  total_points_for=excluded.total_points_for,
  total_points_against=excluded.total_points_against,
  point_difference=excluded.point_difference,
  average_points=excluded.average_points,
  momentum=excluded.momentum,
  consistency=excluded.consistency,
  dominance=excluded.dominance,
  clutch_score=excluded.clutch_score,
  versatility=excluded.versatility,
  schedule_strength=excluded.schedule_strength,
  championships=excluded.championships,
  podiums=excluded.podiums,
  snapshot_source=excluded.snapshot_source,
  captured_at=excluded.captured_at;

do $$
declare
  v_jaksel uuid := (select id from public.flpr_communities where slug='jaksel');
  v_jakut uuid := (select id from public.flpr_communities where slug='jakut');
begin
  if (select count(*) from public.flpr_community_player_statistics
      where community_id=v_jaksel) <> 20 then
    raise exception 'Scoped statistics synchronization failed';
  end if;
  if exists (
    select 1
    from public.player_statistics legacy
    full join public.flpr_community_player_statistics scoped
      on scoped.player_id=legacy.player_id and scoped.community_id=v_jaksel
    where legacy.player_id is null or scoped.player_id is null
       or (to_jsonb(scoped)-'community_id') is distinct from to_jsonb(legacy)
  ) then
    raise exception 'Scoped statistics content parity failed';
  end if;
  if (select count(*) from public.flpr_community_ranking_history
      where community_id=v_jaksel) <> 60 then
    raise exception 'Scoped ranking-history synchronization failed';
  end if;
  if exists(select 1 from public.flpr_community_memberships where community_id=v_jakut)
     or exists(select 1 from public.flpr_community_player_statistics where community_id=v_jakut)
     or exists(select 1 from public.tournaments where community_id=v_jakut)
     or exists(select 1 from public.flpr_community_ranking_history where community_id=v_jakut)
     or exists(select 1 from public.flpr_championship_ranking_history where community_id=v_jakut) then
    raise exception 'Jakut empty-state guard failed';
  end if;
end
$$;

commit;

with ids as (
  select
    (select id from public.flpr_communities where slug='jaksel') jaksel_id,
    (select id from public.flpr_communities where slug='jakut') jakut_id
),
audit as (
  select 'jaksel_statistics_has_20_rows' audit_item,
    (select count(*)=20 from public.flpr_community_player_statistics s,ids
      where s.community_id=ids.jaksel_id) result
  union all
  select 'jaksel_statistics_matches_legacy',not exists(
    select 1 from public.player_statistics legacy
    full join public.flpr_community_player_statistics scoped
      on scoped.player_id=legacy.player_id
     and scoped.community_id=(select jaksel_id from ids)
    where legacy.player_id is null or scoped.player_id is null
       or (to_jsonb(scoped)-'community_id') is distinct from to_jsonb(legacy))
  union all
  select 'jaksel_ranking_history_has_60_rows',
    (select count(*)=60 from public.flpr_community_ranking_history h,ids
      where h.community_id=ids.jaksel_id)
  union all
  select 'jaksel_ranking_history_matches_legacy_count',
    (select count(*) from public.flpr_community_ranking_history h,ids
      where h.community_id=ids.jaksel_id)=(select count(*) from public.ranking_history)
  union all
  select 'jakut_remains_empty',
    not exists(select 1 from public.flpr_community_memberships m,ids where m.community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_community_player_statistics s,ids where s.community_id=ids.jakut_id)
    and not exists(select 1 from public.tournaments t,ids where t.community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_community_ranking_history h,ids where h.community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_championship_ranking_history h,ids where h.community_id=ids.jakut_id)
  union all
  select 'jakut_remains_inactive',
    exists(select 1 from public.flpr_communities where slug='jakut' and status='inactive' and not is_default)
  union all
  select 'legacy_statistics_preserved',(select count(*)=20 from public.player_statistics)
  union all
  select 'legacy_ranking_history_preserved',(select count(*)=60 from public.ranking_history)
  union all
  select 'jaksel_championship_baseline_preserved',
    (select count(*)=20 from public.flpr_championship_ranking_history h,ids
      where h.community_id=ids.jaksel_id)
)
select audit_item,result from audit order by audit_item;

-- FLPR Phase 5.5B-1H
-- Permanent newcomer/default-community statistics synchronization hotfix.
-- Additive only: does not replace flpr_commit_tournament(jsonb).

begin;

create or replace function public.flpr_sync_default_community_statistics()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.flpr_community_player_statistics (
    community_id,player_id,rank,previous_rank,tournaments_played,matches_played,
    wins,draws,losses,win_rate,total_points_for,total_points_against,
    point_difference,average_points,momentum,consistency,dominance,clutch_score,
    versatility,schedule_strength,championships,podiums,updated_at,
    adjusted_win_rate,reliability,raw_composite,official_rating,rating_status,
    confidence_score,player_status,ranking_eligible,current_handicap,
    handicap_provisional
  )
  select
    community.id,new.player_id,new.rank,new.previous_rank,
    new.tournaments_played,new.matches_played,new.wins,new.draws,new.losses,
    new.win_rate,new.total_points_for,new.total_points_against,
    new.point_difference,new.average_points,new.momentum,new.consistency,
    new.dominance,new.clutch_score,new.versatility,new.schedule_strength,
    new.championships,new.podiums,new.updated_at,new.adjusted_win_rate,
    new.reliability,new.raw_composite,new.official_rating,new.rating_status,
    new.confidence_score,new.player_status,new.ranking_eligible,
    player.handicap,player.provisional
  from public.flpr_communities community
  join public.flpr_community_memberships membership
    on membership.community_id=community.id
   and membership.player_id=new.player_id
   and membership.membership_status='active'
  join public.players player on player.id=new.player_id
  where community.status='active'
    and community.is_default=true
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
    ranking_eligible=excluded.ranking_eligible,
    current_handicap=excluded.current_handicap,
    handicap_provisional=excluded.handicap_provisional;

  return new;
end;
$$;

revoke all on function public.flpr_sync_default_community_statistics()
  from public, anon, authenticated;

drop trigger if exists flpr_sync_default_community_statistics
  on public.player_statistics;

create trigger flpr_sync_default_community_statistics
after insert or update on public.player_statistics
for each row
execute function public.flpr_sync_default_community_statistics();

comment on function public.flpr_sync_default_community_statistics() is
  'Phase 5.5B-1H: keeps the active/default community mirror synchronized with legacy ranking recalculation without replacing the production tournament commit function.';

commit;

-- Post-install audit. Every result must be true.
with ids as (
  select id from public.flpr_communities
  where status='active' and is_default=true
),
audit as (
  select 'sync_function_exists' audit_item,
    to_regprocedure('public.flpr_sync_default_community_statistics()') is not null result
  union all
  select 'sync_trigger_enabled',exists(
    select 1 from pg_catalog.pg_trigger
    where tgname='flpr_sync_default_community_statistics'
      and not tgisinternal and tgenabled<>'D')
  union all
  select 'commit_function_preserved',
    md5(p.prosrc)='42a19c9a850b62ed4fd26124fe19444d'
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='flpr_commit_tournament'
    and pg_get_function_identity_arguments(p.oid)='p_preview jsonb'
  union all
  select 'default_community_statistics_complete',not exists(
    select 1
    from public.player_statistics legacy
    join public.flpr_community_memberships membership
      on membership.player_id=legacy.player_id
     and membership.community_id=(select id from ids)
     and membership.membership_status='active'
    left join public.flpr_community_player_statistics scoped
      on scoped.community_id=membership.community_id
     and scoped.player_id=legacy.player_id
    where scoped.player_id is null)
  union all
  select 'michael_k_is_provisional_and_live',exists(
    select 1 from public.v_flpr_public_community_players
    where player_slug='michael-k' and tournaments_played=1
      and matches_played=6 and player_status='PROVISIONAL'
      and ranking_eligible=false and photo_url is not null)
)
select audit_item,result from audit order by audit_item;

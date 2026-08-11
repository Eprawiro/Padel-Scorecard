-- FLPR Phase 5.5B-2N
-- Repair and permanently synchronize community-scoped FLPR ranking history.
-- Idempotent, Jaksel-only through the active/default gate, and fail-closed.

begin;

create or replace function public.flpr_sync_default_community_ranking_history_now(
  p_community_id uuid,
  p_tournament_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_rows integer;
begin
  if not exists (
    select 1
    from public.flpr_communities
    where id=p_community_id and status='active' and is_default=true
  ) then
    raise exception 'Scoped ranking-history synchronization rejected: community must be active/default';
  end if;

  insert into public.flpr_community_ranking_history (
    community_id,legacy_ranking_history_id,snapshot_key,tournament_id,player_id,
    rank,previous_rank,rank_movement,official_rating,adjusted_win_rate,
    reliability,raw_composite,rating_status,tournaments_played,matches_played,
    wins,draws,losses,win_rate,total_points_for,total_points_against,
    point_difference,average_points,momentum,consistency,dominance,clutch_score,
    versatility,schedule_strength,championships,podiums,snapshot_source,captured_at
  )
  select
    p_community_id,legacy.id,legacy.snapshot_key,legacy.tournament_id,
    legacy.player_id,legacy.rank,legacy.previous_rank,legacy.rank_movement,
    legacy.official_rating,legacy.adjusted_win_rate,legacy.reliability,
    legacy.raw_composite,legacy.rating_status,legacy.tournaments_played,
    legacy.matches_played,legacy.wins,legacy.draws,legacy.losses,legacy.win_rate,
    legacy.total_points_for,legacy.total_points_against,legacy.point_difference,
    legacy.average_points,legacy.momentum,legacy.consistency,legacy.dominance,
    legacy.clutch_score,legacy.versatility,legacy.schedule_strength,
    legacy.championships,legacy.podiums,legacy.snapshot_source,legacy.captured_at
  from public.ranking_history legacy
  join public.flpr_community_memberships membership
    on membership.community_id=p_community_id
   and membership.player_id=legacy.player_id
  where p_tournament_id is null or legacy.tournament_id=p_tournament_id
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

  get diagnostics v_rows = row_count;

  if exists (
    select 1
    from public.ranking_history legacy
    join public.flpr_community_memberships membership
      on membership.community_id=p_community_id
     and membership.player_id=legacy.player_id
    left join public.flpr_community_ranking_history scoped
      on scoped.community_id=p_community_id
     and scoped.snapshot_key=legacy.snapshot_key
     and scoped.player_id=legacy.player_id
    where (p_tournament_id is null or legacy.tournament_id=p_tournament_id)
      and (
        scoped.id is null
        or scoped.tournament_id is distinct from legacy.tournament_id
        or scoped.rank is distinct from legacy.rank
        or scoped.previous_rank is distinct from legacy.previous_rank
        or scoped.rank_movement is distinct from legacy.rank_movement
        or scoped.official_rating is distinct from legacy.official_rating
      )
  ) then
    raise exception 'Scoped ranking-history parity validation failed';
  end if;

  return v_rows;
end;
$$;

revoke all on function public.flpr_sync_default_community_ranking_history_now(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.flpr_sync_default_community_ranking_history_now(uuid,uuid)
  to service_role;

-- Repair the latest published default-community tournament. If the legacy
-- snapshot itself is missing, capture it first from the already committed
-- current rankings; otherwise this block only mirrors existing verified rows.
do $$
declare
  v_community_id uuid;
  v_tournament_id uuid;
begin
  select id into strict v_community_id
  from public.flpr_communities
  where status='active' and is_default=true;

  select id into strict v_tournament_id
  from public.tournaments
  where community_id=v_community_id and status='published'
  order by coalesce(published_at,imported_at,created_at) desc,id desc
  limit 1;

  if not exists (
    select 1 from public.ranking_history where tournament_id=v_tournament_id
  ) then
    perform public.flpr_capture_ranking_snapshot(
      v_tournament_id,null,'scoped-history-repair'
    );
  end if;

  perform public.flpr_sync_default_community_ranking_history_now(
    v_community_id,v_tournament_id
  );
end;
$$;

-- Integrate scoped history immediately after every future legacy FLPR capture.
do $$
declare
  v_oid oid;
  v_source text;
  v_definition text;
  v_old_fragment text :=
    'perform public.flpr_capture_ranking_snapshot(' || chr(10) ||
    '    v_tournament_id, null, ''tournament-commit''' || chr(10) ||
    '  );';
  v_new_fragment text := v_old_fragment || chr(10) || chr(10) ||
    '  -- Phase 5.5B-2N: mirror the verified FLPR snapshot in the same transaction.' || chr(10) ||
    '  perform public.flpr_sync_default_community_ranking_history_now(' || chr(10) ||
    '    v_community_id, v_tournament_id' || chr(10) ||
    '  );';
begin
  select p.oid,p.prosrc,pg_get_functiondef(p.oid)
    into v_oid,v_source,v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='flpr_commit_tournament'
    and pg_get_function_identity_arguments(p.oid)='p_preview jsonb';

  if v_oid is null then
    raise exception '5.5B-2N aborted: production commit function not found';
  end if;
  if position('flpr_sync_default_community_ranking_history_now' in v_definition)>0 then
    return;
  end if;
  if md5(v_source)<>'bfb1e1edbb4b227f514420ca141386c8' then
    raise exception '5.5B-2N aborted: unexpected production function hash %',md5(v_source);
  end if;
  if position(v_old_fragment in v_definition)=0 then
    raise exception '5.5B-2N aborted: verified ranking-snapshot injection point not found';
  end if;

  v_definition := replace(v_definition,v_old_fragment,v_new_fragment);
  execute v_definition;
end;
$$;

revoke all on function public.flpr_commit_tournament(jsonb)
  from public, anon, authenticated;
grant execute on function public.flpr_commit_tournament(jsonb)
  to service_role;

comment on function public.flpr_commit_tournament(jsonb) is
  'Atomic verified tournament publish with calculation, default-community statistics sync, legacy and scoped FLPR snapshots, and Championship snapshot. Phase 5.5B-2N.';

commit;

-- Post-install audit. Every result must be true.
with ids as (
  select
    (select id from public.flpr_communities where slug='jaksel') jaksel_id,
    (select id from public.flpr_communities where slug='jakut') jakut_id
), latest as (
  select t.id
  from public.tournaments t,ids
  where t.community_id=ids.jaksel_id and t.status='published'
  order by coalesce(t.published_at,t.imported_at,t.created_at) desc,t.id desc
  limit 1
), function_state as (
  select p.prosrc,p.prosecdef,md5(p.prosrc) function_hash
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='flpr_commit_tournament'
    and pg_get_function_identity_arguments(p.oid)='p_preview jsonb'
), latest_legacy as (
  select * from public.ranking_history where tournament_id=(select id from latest)
), latest_scoped as (
  select h.* from public.flpr_community_ranking_history h,ids
  where h.community_id=ids.jaksel_id
    and h.tournament_id=(select id from latest)
), audit as (
  select 'latest_legacy_snapshot_exists' audit_item,
    exists(select 1 from latest_legacy) result,
    (select count(*)::text||' rows' from latest_legacy) details
  union all
  select 'latest_scoped_snapshot_complete',
    (select count(*) from latest_scoped)=(select count(*) from latest_legacy)
      and exists(select 1 from latest_scoped),
    (select count(*)::text||' scoped / '||(select count(*) from latest_legacy)::text||' legacy' from latest_scoped limit 1)
  union all
  select 'edy_latest_current_values_captured',exists(
    select 1
    from latest_scoped h
    join public.players p on p.id=h.player_id
    where lower(trim(p.display_name))='edy sp'
      and h.rank=13 and round(h.official_rating,2)=47.81
  ),'Expected Rank #13 / Rating 47.81'
  union all
  select 'future_scoped_sync_integrated',coalesce((select
    prosrc like '%flpr_sync_default_community_ranking_history_now%'
    from function_state),false),'Scoped FLPR history is atomic with publish'
  union all
  select 'commit_security_preserved',coalesce((select prosecdef from function_state),false)
    and has_function_privilege('service_role','public.flpr_commit_tournament(jsonb)','EXECUTE')
    and not has_function_privilege('anon','public.flpr_commit_tournament(jsonb)','EXECUTE')
    and not has_function_privilege('authenticated','public.flpr_commit_tournament(jsonb)','EXECUTE'),
    'Security definer; service role only'
  union all
  select 'jakut_activation_gate_preserved',
    exists(select 1 from public.flpr_communities where slug='jakut' and status='inactive' and not is_default)
    and not exists(select 1 from public.flpr_community_ranking_history h,ids where h.community_id=ids.jakut_id),
    'Jakut inactive and history remains empty'
)
select audit_item,result,details from audit order by audit_item;

-- FLPR Phase 5.5B-2M
-- Atomic scoped publish integration.
-- Fail-closed installer for the verified production commit-function baseline.

begin;

create or replace function public.flpr_sync_default_community_statistics_now(
  p_community_id uuid
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
    select 1 from public.flpr_communities
    where id=p_community_id and status='active' and is_default=true
  ) then
    raise exception 'Scoped synchronization rejected: community must be active/default';
  end if;

  if exists (
    select 1
    from public.flpr_community_memberships membership
    left join public.player_statistics legacy
      on legacy.player_id=membership.player_id
    where membership.community_id=p_community_id
      and membership.membership_status='active'
      and legacy.player_id is null
  ) then
    raise exception 'Scoped synchronization rejected: active member without legacy statistics';
  end if;

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
    p_community_id,legacy.player_id,legacy.rank,legacy.previous_rank,
    legacy.tournaments_played,legacy.matches_played,legacy.wins,legacy.draws,
    legacy.losses,legacy.win_rate,legacy.total_points_for,
    legacy.total_points_against,legacy.point_difference,legacy.average_points,
    legacy.momentum,legacy.consistency,legacy.dominance,legacy.clutch_score,
    legacy.versatility,legacy.schedule_strength,legacy.championships,
    legacy.podiums,legacy.updated_at,legacy.adjusted_win_rate,
    legacy.reliability,legacy.raw_composite,legacy.official_rating,
    legacy.rating_status,legacy.confidence_score,legacy.player_status,
    legacy.ranking_eligible,player.handicap,player.provisional
  from public.player_statistics legacy
  join public.players player on player.id=legacy.player_id
  join public.flpr_community_memberships membership
    on membership.community_id=p_community_id
   and membership.player_id=legacy.player_id
   and membership.membership_status='active'
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

  get diagnostics v_rows = row_count;

  if exists (
    select 1
    from public.player_statistics legacy
    join public.flpr_community_memberships membership
      on membership.community_id=p_community_id
     and membership.player_id=legacy.player_id
     and membership.membership_status='active'
    left join public.flpr_community_player_statistics scoped
      on scoped.community_id=p_community_id
     and scoped.player_id=legacy.player_id
    where scoped.player_id is null
       or (to_jsonb(scoped)-'community_id'-'current_handicap'-'handicap_provisional')
          is distinct from to_jsonb(legacy)
       or scoped.current_handicap is distinct from
          (select handicap from public.players where id=legacy.player_id)
       or scoped.handicap_provisional is distinct from
          (select provisional from public.players where id=legacy.player_id)
  ) then
    raise exception 'Scoped synchronization parity validation failed';
  end if;

  return v_rows;
end;
$$;

revoke all on function public.flpr_sync_default_community_statistics_now(uuid)
  from public, anon, authenticated;
grant execute on function public.flpr_sync_default_community_statistics_now(uuid)
  to service_role;

do $$
declare
  v_oid oid;
  v_source text;
  v_definition text;
  v_old_fragment text := 'perform public.flpr_recalculate_rankings();';
  v_new_fragment text :=
    'perform public.flpr_recalculate_rankings();' || chr(10) || chr(10) ||
    '  -- Phase 5.5B-2M: scoped statistics are part of the same publish transaction.' || chr(10) ||
    '  perform public.flpr_sync_default_community_statistics_now(v_community_id);';
begin
  select p.oid,p.prosrc,pg_get_functiondef(p.oid)
    into v_oid,v_source,v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='flpr_commit_tournament'
    and pg_get_function_identity_arguments(p.oid)='p_preview jsonb';

  if v_oid is null then
    raise exception '5.5B-2M aborted: production commit function not found';
  end if;
  if md5(v_source) <> '42a19c9a850b62ed4fd26124fe19444d' then
    raise exception '5.5B-2M aborted: unexpected production function hash %',md5(v_source);
  end if;
  if position(v_old_fragment in v_definition)=0 then
    raise exception '5.5B-2M aborted: verified injection point not found';
  end if;
  if position('flpr_sync_default_community_statistics_now' in v_definition)>0 then
    raise exception '5.5B-2M aborted: scoped sync is already integrated';
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
  'Atomic verified tournament publish with ranking calculation, direct default-community statistics synchronization, FLPR snapshot, and Championship snapshot. Phase 5.5B-2M.';

commit;

-- Post-install audit. Every result must be true.
with ids as (
  select
    (select id from public.flpr_communities where slug='jaksel') jaksel_id,
    (select id from public.flpr_communities where slug='jakut') jakut_id
),
function_state as (
  select p.prosrc,p.prosecdef,md5(p.prosrc) function_hash
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='flpr_commit_tournament'
    and pg_get_function_identity_arguments(p.oid)='p_preview jsonb'
),
helper_state as (
  select p.prosecdef
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='flpr_sync_default_community_statistics_now'
    and pg_get_function_identity_arguments(p.oid)='p_community_id uuid'
),
audit as (
  select 'commit_function_updated' audit_item,
    coalesce((select function_hash<>'42a19c9a850b62ed4fd26124fe19444d' from function_state),false) result,
    coalesce((select function_hash from function_state),'missing') details
  union all
  select 'direct_scoped_sync_integrated',coalesce((select
    prosrc like '%flpr_sync_default_community_statistics_now(v_community_id)%'
    from function_state),false),'Directly after legacy recalculation'
  union all
  select 'existing_atomic_steps_preserved',coalesce((select
    prosrc like '%flpr_recalculate_rankings%'
    and prosrc like '%flpr_capture_ranking_snapshot%'
    and prosrc like '%flpr_capture_championship_snapshot_v1%'
    from function_state),false),'Calculation + both snapshots'
  union all
  select 'commit_security_preserved',coalesce((select prosecdef from function_state),false)
    and has_function_privilege('service_role','public.flpr_commit_tournament(jsonb)','EXECUTE')
    and not has_function_privilege('anon','public.flpr_commit_tournament(jsonb)','EXECUTE')
    and not has_function_privilege('authenticated','public.flpr_commit_tournament(jsonb)','EXECUTE'),
    'Security definer; service role only'
  union all
  select 'scoped_sync_helper_secured',coalesce((select prosecdef from helper_state),false)
    and has_function_privilege('service_role','public.flpr_sync_default_community_statistics_now(uuid)','EXECUTE')
    and not has_function_privilege('anon','public.flpr_sync_default_community_statistics_now(uuid)','EXECUTE')
    and not has_function_privilege('authenticated','public.flpr_sync_default_community_statistics_now(uuid)','EXECUTE'),
    'Security definer; service role only'
  union all
  select 'safety_trigger_preserved',exists(select 1 from pg_catalog.pg_trigger
    where tgname='flpr_sync_default_community_statistics'
      and not tgisinternal and tgenabled<>'D'),'5.5B-1H fallback remains enabled'
  union all
  select 'jaksel_statistics_complete',
    (select count(*) from public.flpr_community_memberships m,ids
      where m.community_id=ids.jaksel_id and m.membership_status='active')
    =
    (select count(*) from public.flpr_community_player_statistics s,ids
      where s.community_id=ids.jaksel_id),'Active memberships equal statistics rows'
  union all
  select 'jakut_activation_gate_preserved',
    exists(select 1 from public.flpr_communities where slug='jakut' and status='inactive' and not is_default)
    and not exists(select 1 from public.flpr_community_memberships m,ids where m.community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_community_player_statistics s,ids where s.community_id=ids.jakut_id)
    and not exists(select 1 from public.tournaments t,ids where t.community_id=ids.jakut_id),
    'Jakut inactive and empty'
  union all
  select 'michael_k_regression_guard',exists(select 1
    from public.v_flpr_public_community_players where community_slug='jaksel'
      and player_slug='michael-k' and rank=4 and tournaments_played=1
      and matches_played=6 and official_rating=65.3807
      and player_status='PROVISIONAL' and ranking_eligible=false
      and photo_url is not null),'T8 newcomer remains correct'
)
select audit_item,result,details from audit order by audit_item;

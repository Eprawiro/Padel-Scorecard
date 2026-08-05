-- FLPR Phase 5.4D — Restricted manual Championship snapshot function
-- Creates the function only. It does NOT invoke it and creates NO trigger.

begin;

create or replace function public.flpr_capture_championship_snapshot_v1(
  p_community_id uuid,
  p_tournament_id uuid,
  p_snapshot_source text default 'manual_baseline'
)
returns table (
  inserted_count integer,
  skipped_count integer,
  captured_snapshot_key text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_latest_tournament_id uuid;
  v_snapshot_key text;
  v_candidate_count integer;
  v_inserted_count integer;
begin
  if p_snapshot_source not in ('manual_baseline', 'tournament_publish') then
    raise exception 'Unsupported Championship snapshot source: %', p_snapshot_source;
  end if;

  -- Championship v1 is currently activated only for the flagship/default
  -- community. Reject every other community instead of leaking Jaksel scores.
  if not exists (
    select 1
    from public.flpr_communities community
    where community.id = p_community_id
      and community.status = 'active'
      and community.is_default = true
  ) then
    raise exception 'Championship v1 capture is restricted to the active default community';
  end if;

  select tournament.id
  into v_latest_tournament_id
  from public.tournaments tournament
  where tournament.community_id = p_community_id
    and tournament.status = 'published'
  order by
    coalesce(tournament.tournament_date, tournament.published_at::date,
      tournament.imported_at::date, tournament.created_at::date) desc,
    tournament.id desc
  limit 1;

  if v_latest_tournament_id is null then
    raise exception 'No published tournament exists for community %', p_community_id;
  end if;

  if v_latest_tournament_id <> p_tournament_id then
    raise exception 'Snapshot target must be the latest published tournament. Expected %, received %',
      v_latest_tournament_id, p_tournament_id;
  end if;

  v_snapshot_key := concat('championship-v1:', p_tournament_id::text);

  select count(*)::integer
  into v_candidate_count
  from public.v_flpr_championship_ranking_v1 ranking
  join public.flpr_community_memberships membership
    on membership.community_id = p_community_id
    and membership.player_id = ranking.player_id
    and membership.membership_status = 'active';

  if v_candidate_count = 0 then
    raise exception 'Championship ranking returned no active capture candidates';
  end if;

  if v_candidate_count <> (
    select count(*)::integer
    from public.flpr_community_memberships membership
    where membership.community_id = p_community_id
      and membership.membership_status = 'active'
  ) then
    raise exception 'Championship ranking coverage does not match active community membership';
  end if;

  insert into public.flpr_championship_ranking_history (
    community_id, tournament_id, player_id, calculation_version, snapshot_key,
    championship_rank, previous_rank, rank_movement,
    championship_score, previous_score, score_change,
    championship_eligibility, rolling_appearances, raw_rolling_points,
    confidence_factor, inactivity_factor, championships, podiums, best_finish,
    latest_event_date, snapshot_source, captured_at
  )
  select
    p_community_id,
    p_tournament_id,
    ranking.player_id,
    'championship-v1',
    v_snapshot_key,
    ranking.championship_rank,
    previous.championship_rank,
    case when previous.championship_rank is null then null
      else previous.championship_rank - ranking.championship_rank end,
    ranking.championship_score,
    previous.championship_score,
    case when previous.championship_score is null then null
      else round(ranking.championship_score - previous.championship_score, 2) end,
    ranking.championship_eligibility,
    ranking.rolling_appearances,
    ranking.raw_rolling_points,
    ranking.confidence_factor,
    ranking.inactivity_factor,
    ranking.championships,
    ranking.podiums,
    ranking.best_finish,
    ranking.latest_event_date,
    p_snapshot_source,
    now()
  from public.v_flpr_championship_ranking_v1 ranking
  join public.flpr_community_memberships membership
    on membership.community_id = p_community_id
    and membership.player_id = ranking.player_id
    and membership.membership_status = 'active'
  left join lateral (
    select history.championship_rank, history.championship_score
    from public.flpr_championship_ranking_history history
    where history.community_id = p_community_id
      and history.player_id = ranking.player_id
      and history.calculation_version = 'championship-v1'
    order by history.captured_at desc, history.id desc
    limit 1
  ) previous on true
  on conflict (community_id, tournament_id, player_id, calculation_version)
  do nothing;

  get diagnostics v_inserted_count = row_count;

  return query
  select
    v_inserted_count,
    v_candidate_count - v_inserted_count,
    v_snapshot_key;
end;
$$;

revoke all on function public.flpr_capture_championship_snapshot_v1(uuid, uuid, text)
  from public, anon, authenticated;

grant execute on function public.flpr_capture_championship_snapshot_v1(uuid, uuid, text)
  to service_role;

comment on function public.flpr_capture_championship_snapshot_v1(uuid, uuid, text) is
  'Restricted, idempotent Championship Ranking v1 snapshot capture. Manual/service-role only; no trigger attached.';

commit;

-- Post-install audit. Expected: every result is true and history remains empty.
with audit as (
  select 'function_exists'::text as audit_item,
    to_regprocedure('public.flpr_capture_championship_snapshot_v1(uuid,uuid,text)') is not null as result
  union all
  select 'function_is_security_definer',
    (select p.prosecdef from pg_proc p
      where p.oid = 'public.flpr_capture_championship_snapshot_v1(uuid,uuid,text)'::regprocedure)
  union all
  select 'service_role_can_execute',
    has_function_privilege('service_role',
      'public.flpr_capture_championship_snapshot_v1(uuid,uuid,text)', 'EXECUTE')
  union all
  select 'anon_cannot_execute',
    not has_function_privilege('anon',
      'public.flpr_capture_championship_snapshot_v1(uuid,uuid,text)', 'EXECUTE')
  union all
  select 'authenticated_cannot_execute',
    not has_function_privilege('authenticated',
      'public.flpr_capture_championship_snapshot_v1(uuid,uuid,text)', 'EXECUTE')
  union all
  select 'history_remains_empty',
    (select count(*) = 0 from public.flpr_championship_ranking_history)
  union all
  select 'no_capture_trigger_enabled',
    not exists (
      select 1 from pg_trigger tr
      join pg_class cl on cl.oid = tr.tgrelid
      join pg_namespace ns on ns.oid = cl.relnamespace
      where ns.nspname = 'public'
        and not tr.tgisinternal
        and (tr.tgname ilike '%championship%' or pg_get_triggerdef(tr.oid) ilike '%championship%')
    )
  union all
  select 'current_championship_view_preserved',
    (select count(*) = 20 from public.v_flpr_championship_ranking_v1)
  union all
  select 'existing_flpr_history_preserved',
    (select count(*) = 40 from public.flpr_community_ranking_history)
)
select audit_item, result
from audit
order by audit_item;

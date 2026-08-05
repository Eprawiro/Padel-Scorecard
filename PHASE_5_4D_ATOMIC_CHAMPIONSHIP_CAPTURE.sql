-- FLPR Phase 5.4D
-- Atomic Championship snapshot integration for verified tournament publishing.
-- Replaces only flpr_commit_tournament(jsonb); creates no trigger.

begin;

create or replace function public.flpr_commit_tournament(p_preview jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, flpr
as $$
declare
  v_tournament_id uuid;
  v_community_id uuid;
  v_log_id uuid;
  v_row jsonb;
  v_match jsonb;
  v_player uuid;
  v_tp uuid;
  v_match_id uuid;
  v_name text;
  v_slug text;
  v_source_id text := p_preview->>'sourceId';
  v_fingerprint text := p_preview->>'fingerprint';
begin
  if coalesce(p_preview#>>'{validation,status}','FAIL') = 'FAIL' then
    raise exception 'Preview validation failed';
  end if;
  if v_source_id is null or v_source_id = '' then
    raise exception 'Missing sourceId';
  end if;
  if exists (
    select 1 from public.tournaments
    where source_provider = 'americano-padel'
      and source_tournament_id = v_source_id
      and status <> 'rolled_back'
  ) then
    raise exception 'Tournament already imported';
  end if;

  insert into public.import_logs (
    source_url, source_tournament_id, source_fingerprint, operation, status,
    existing_players, new_players, rounds_detected, matches_detected,
    preview_payload
  )
  values (
    p_preview->>'sourceUrl', v_source_id, v_fingerprint, 'confirm', 'started',
    coalesce((p_preview#>>'{summary,existingPlayers}')::int,0),
    coalesce((p_preview#>>'{summary,newPlayers}')::int,0),
    coalesce((p_preview#>>'{summary,rounds}')::int,0),
    coalesce((p_preview#>>'{summary,matches}')::int,0), p_preview
  )
  returning id into v_log_id;

  insert into public.tournaments (
    source_provider, source_tournament_id, source_url, source_fingerprint,
    name, status, player_count, round_count, match_count, imported_at,
    published_at, raw_payload
  )
  values (
    'americano-padel', v_source_id, p_preview->>'sourceUrl', v_fingerprint,
    coalesce(nullif(p_preview->>'title',''),'Americano Tournament'),
    'published',
    coalesce((p_preview#>>'{summary,players}')::int,0),
    coalesce((p_preview#>>'{summary,rounds}')::int,0),
    coalesce((p_preview#>>'{summary,matches}')::int,0),
    now(), now(), p_preview
  )
  returning id, community_id into v_tournament_id, v_community_id;

  if v_community_id is null then
    raise exception 'Tournament community could not be resolved';
  end if;

  for v_row in
    select * from jsonb_array_elements(coalesce(p_preview->'standings','[]'::jsonb))
  loop
    v_name := trim(v_row->>'name');
    v_player := nullif(v_row->>'matchedPlayerId','')::uuid;
    if v_player is null then
      v_slug := regexp_replace(
        lower(flpr.normalize_player_name(v_name)), '[^a-z0-9]+', '-', 'g'
      );
      v_slug := trim(both '-' from v_slug);
      insert into public.players(display_name,slug,provisional)
      values(v_name,v_slug,true)
      on conflict (normalized_name) where status <> 'merged'
      do update set display_name = excluded.display_name
      returning id into v_player;

      insert into public.player_statistics(player_id)
      values(v_player)
      on conflict do nothing;
    end if;

    -- Phase 5.4D: every published participant must belong to the tournament's
    -- community before the community-scoped Championship snapshot is captured.
    insert into public.flpr_community_memberships as membership (
      community_id, player_id, membership_status, local_display_name
    )
    values (v_community_id, v_player, 'active', v_name)
    on conflict (community_id, player_id) do update set
      membership_status = 'active',
      local_display_name = coalesce(membership.local_display_name,
        excluded.local_display_name),
      updated_at = now();

    insert into public.tournament_players (
      tournament_id, player_id, source_player_name, identity_status,
      final_position, total_points, point_difference, wins, draws, losses,
      matches_played, is_champion
    )
    values (
      v_tournament_id, v_player, v_name,
      case lower(trim(coalesce(v_row->>'matchStatus', '')))
        when 'existing' then 'exact'
        when 'exact' then 'exact'
        when 'alias' then 'alias'
        when 'manual' then 'manual'
        when 'unresolved' then 'unresolved'
        when 'new' then 'new'
        else 'new'
      end,
      nullif(v_row->>'rank','')::int,
      coalesce((v_row->>'points')::numeric,0),
      coalesce((v_row->>'diff')::numeric,0),
      coalesce((v_row->>'wins')::int,0),
      coalesce((v_row->>'ties')::int,0),
      coalesce((v_row->>'losses')::int,0),
      coalesce((v_row->>'wins')::int,0)
        + coalesce((v_row->>'ties')::int,0)
        + coalesce((v_row->>'losses')::int,0),
      coalesce((v_row->>'rank')::int,999) = 1
    )
    returning id into v_tp;
  end loop;

  for v_match in
    select * from jsonb_array_elements(coalesce(p_preview->'matches','[]'::jsonb))
  loop
    insert into public.matches (
      tournament_id, round_number, court_label, match_number,
      team_a_score, team_b_score, status, raw_payload
    )
    values (
      v_tournament_id, (v_match->>'round')::int, v_match->>'court', 0,
      (v_match->>'scoreA')::numeric, (v_match->>'scoreB')::numeric,
      case when coalesce((v_match->>'completed')::boolean,false)
        then 'completed' else 'scheduled' end,
      v_match
    )
    returning id into v_match_id;

    for v_name in select value from jsonb_array_elements_text(v_match->'teamA')
    loop
      select tp.id into v_tp
      from public.tournament_players tp
      where tp.tournament_id = v_tournament_id
        and tp.source_player_key = flpr.normalize_player_name(v_name);
      if v_tp is not null then
        insert into public.match_players (
          match_id, tournament_player_id, team_no, team_slot,
          points_scored, points_conceded, result
        )
        values (
          v_match_id, v_tp, 1,
          case when not exists (
            select 1 from public.match_players
            where match_id = v_match_id and team_no = 1
          ) then 1 else 2 end,
          (v_match->>'scoreA')::numeric,
          (v_match->>'scoreB')::numeric,
          case
            when (v_match->>'scoreA')::numeric > (v_match->>'scoreB')::numeric then 'win'
            when (v_match->>'scoreA')::numeric < (v_match->>'scoreB')::numeric then 'loss'
            else 'draw'
          end
        );
      end if;
    end loop;

    for v_name in select value from jsonb_array_elements_text(v_match->'teamB')
    loop
      select tp.id into v_tp
      from public.tournament_players tp
      where tp.tournament_id = v_tournament_id
        and tp.source_player_key = flpr.normalize_player_name(v_name);
      if v_tp is not null then
        insert into public.match_players (
          match_id, tournament_player_id, team_no, team_slot,
          points_scored, points_conceded, result
        )
        values (
          v_match_id, v_tp, 2,
          case when not exists (
            select 1 from public.match_players
            where match_id = v_match_id and team_no = 2
          ) then 1 else 2 end,
          (v_match->>'scoreB')::numeric,
          (v_match->>'scoreA')::numeric,
          case
            when (v_match->>'scoreB')::numeric > (v_match->>'scoreA')::numeric then 'win'
            when (v_match->>'scoreB')::numeric < (v_match->>'scoreA')::numeric then 'loss'
            else 'draw'
          end
        );
      end if;
    end loop;
  end loop;

  perform public.flpr_recalculate_rankings();

  -- Preserve the existing post-tournament FLPR snapshot.
  perform public.flpr_capture_ranking_snapshot(
    v_tournament_id, null, 'tournament-commit'
  );

  -- Phase 5.4D: capture Championship v1 inside the same transaction, after
  -- tournament data and calculations are complete. Any failure rolls back the
  -- entire verified publish; no loose trigger or partial snapshot is possible.
  perform 1
  from public.flpr_capture_championship_snapshot_v1(
    v_community_id, v_tournament_id, 'tournament_publish'
  );

  update public.import_logs
  set status = 'committed', tournament_id = v_tournament_id, completed_at = now()
  where id = v_log_id;

  insert into public.audit_log (
    entity_type, entity_id, action, new_data, import_log_id
  )
  values (
    'tournament', v_tournament_id::text, 'confirm_import', p_preview, v_log_id
  );

  return jsonb_build_object(
    'ok', true,
    'tournamentId', v_tournament_id,
    'communityId', v_community_id,
    'importLogId', v_log_id,
    'championshipSnapshot', 'captured'
  );
exception when others then
  if v_log_id is not null then
    update public.import_logs
    set status = 'failed', error_message = sqlerrm, completed_at = now()
    where id = v_log_id;
  end if;
  raise;
end;
$$;

revoke all on function public.flpr_commit_tournament(jsonb)
  from public, anon, authenticated;
grant execute on function public.flpr_commit_tournament(jsonb)
  to service_role;

comment on function public.flpr_commit_tournament(jsonb) is
  'Atomic verified tournament commit with FLPR and Championship v1 snapshots. Phase 5.4D.';

commit;

-- Installation audit. Expected: all result values are true.
with function_state as (
  select
    p.oid,
    p.prosrc,
    p.prosecdef
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'flpr_commit_tournament'
    and p.prokind = 'f'
    and p.pronargs = 1
),
audit as (
  select 'commit_function_exists'::text as audit_item,
    exists(select 1 from function_state) as result
  union all
  select 'commit_is_security_definer',
    coalesce((select prosecdef from function_state limit 1), false)
  union all
  select 'service_role_can_execute',
    has_function_privilege(
      'service_role', 'public.flpr_commit_tournament(jsonb)', 'EXECUTE'
    )
  union all
  select 'anon_cannot_execute',
    not has_function_privilege(
      'anon', 'public.flpr_commit_tournament(jsonb)', 'EXECUTE'
    )
  union all
  select 'authenticated_cannot_execute',
    not has_function_privilege(
      'authenticated', 'public.flpr_commit_tournament(jsonb)', 'EXECUTE'
    )
  union all
  select 'community_membership_is_transactional',
    coalesce((select prosrc like '%insert into public.flpr_community_memberships%'
      from function_state limit 1), false)
  union all
  select 'flpr_snapshot_is_preserved',
    coalesce((select prosrc like '%flpr_capture_ranking_snapshot%'
      from function_state limit 1), false)
  union all
  select 'championship_snapshot_is_atomic',
    coalesce((select prosrc like '%flpr_capture_championship_snapshot_v1%'
      from function_state limit 1), false)
  union all
  select 'championship_source_is_tournament_publish',
    coalesce((select prosrc like '%''tournament_publish''%'
      from function_state limit 1), false)
  union all
  select 'no_championship_trigger_enabled',
    not exists (
      select 1
      from pg_catalog.pg_trigger trigger
      join pg_catalog.pg_proc function on function.oid = trigger.tgfoid
      where not trigger.tgisinternal
        and (
          trigger.tgname ilike '%championship%'
          or function.proname ilike '%championship%'
        )
    )
  union all
  select 't7_baseline_still_20_rows',
    (select count(*) = 20
      from public.flpr_championship_ranking_history
      where snapshot_source = 'manual_baseline')
  union all
  select 'existing_flpr_history_preserved',
    (select count(*) = 60 from public.ranking_history)
)
select audit_item, result
from audit
order by audit_item;

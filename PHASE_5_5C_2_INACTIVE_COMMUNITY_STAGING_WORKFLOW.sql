-- FLPR Phase 5.5C-2
-- INACTIVE-COMMUNITY VERIFIED TOURNAMENT STAGING WORKFLOW
--
-- Adds a separate, explicit-community transaction for staging verified raw
-- tournament data. It never invokes the legacy/global ranking calculator,
-- never writes FLPR/Championship snapshots, never publishes publicly, and
-- never changes the existing Jaksel production publisher.

begin;

create table if not exists public.flpr_community_staging_log (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null
    references public.flpr_communities(id) on delete restrict,
  tournament_id uuid references public.tournaments(id) on delete set null,
  source_provider text not null default 'americano-padel',
  source_tournament_id text not null,
  source_fingerprint text,
  staging_status text not null default 'started'
    check (staging_status in ('started','verified','discarded')),
  player_count integer not null default 0 check (player_count>=0),
  match_count integer not null default 0 check (match_count>=0),
  preview_payload jsonb not null,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists flpr_community_staging_log_scope_idx
  on public.flpr_community_staging_log(community_id,created_at desc);

-- Preserve every discarded attempt in the audit trail while preventing two
-- live staging records for the same source tournament. A corrected source can
-- therefore be staged again only after the earlier attempt is discarded.
create unique index if not exists flpr_community_staging_log_live_source_uidx
  on public.flpr_community_staging_log(
    community_id,source_provider,source_tournament_id
  ) where staging_status in ('started','verified');

alter table public.flpr_community_staging_log enable row level security;

drop policy if exists flpr_assigned_admin_reads_staging_log
  on public.flpr_community_staging_log;
create policy flpr_assigned_admin_reads_staging_log
  on public.flpr_community_staging_log for select to authenticated
  using (public.flpr_has_community_access(
    community_id,array['owner','admin','viewer']));

revoke all on public.flpr_community_staging_log from public,anon,authenticated;
grant select on public.flpr_community_staging_log to authenticated,service_role;

create or replace function public.flpr_stage_community_tournament(
  p_community_id uuid,
  p_preview jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, flpr, pg_temp
as $$
declare
  v_community public.flpr_communities;
  v_tournament_id uuid;
  v_stage_id uuid;
  v_row jsonb;
  v_match jsonb;
  v_player uuid;
  v_tp uuid;
  v_match_id uuid;
  v_name text;
  v_slug text;
  v_alias_key text;
  v_source_id text := lower(trim(coalesce(p_preview->>'sourceId','')));
  v_fingerprint text := trim(coalesce(p_preview->>'fingerprint',''));
  v_standing_count integer;
  v_match_count integer;
begin
  if not public.flpr_has_community_access(
    p_community_id,array['owner','admin']
  ) then
    raise exception 'Community Owner or Admin access required';
  end if;

  select * into v_community
  from public.flpr_communities where id=p_community_id for update;
  if v_community.id is null then raise exception 'Community not found'; end if;
  if v_community.is_default or v_community.status<>'inactive' then
    raise exception 'Staging requires an inactive, non-default community';
  end if;

  if coalesce(p_preview#>>'{validation,status}','FAIL')='FAIL' then
    raise exception 'Preview validation failed';
  end if;
  if v_source_id='' then raise exception 'Missing sourceId'; end if;
  if v_fingerprint='' then raise exception 'Missing source fingerprint'; end if;

  v_standing_count := jsonb_array_length(
    coalesce(p_preview->'standings','[]'::jsonb));
  v_match_count := jsonb_array_length(
    coalesce(p_preview->'matches','[]'::jsonb));
  if v_standing_count<4 then
    raise exception 'A staged tournament requires at least four standings rows';
  end if;
  if v_match_count<1 then
    raise exception 'A staged tournament requires verified match rows';
  end if;
  if coalesce((p_preview#>>'{summary,players}')::integer,0)
     <>v_standing_count then
    raise exception 'Preview player count does not match standings';
  end if;
  if coalesce((p_preview#>>'{summary,matches}')::integer,0)
     <>v_match_count then
    raise exception 'Preview match count does not match match rows';
  end if;

  if exists(
    select 1 from public.tournaments
    where source_provider='americano-padel'
      and source_tournament_id=v_source_id
      and status<>'rolled_back'
  ) then
    raise exception 'Tournament already exists';
  end if;

  insert into public.flpr_community_staging_log(
    community_id,source_tournament_id,source_fingerprint,staging_status,
    player_count,match_count,preview_payload,created_by
  ) values (
    p_community_id,v_source_id,v_fingerprint,'started',
    v_standing_count,v_match_count,p_preview,auth.uid()
  )
  returning id into v_stage_id;

  insert into public.tournaments(
    community_id,source_provider,source_tournament_id,source_url,
    source_fingerprint,name,status,player_count,round_count,match_count,
    imported_at,published_at,raw_payload
  ) values (
    p_community_id,'americano-padel',v_source_id,p_preview->>'sourceUrl',
    v_fingerprint,
    coalesce(nullif(trim(p_preview->>'title'),''),'Americano Tournament'),
    'verified',v_standing_count,
    coalesce((p_preview#>>'{summary,rounds}')::integer,0),
    v_match_count,now(),null,p_preview
  )
  returning id into v_tournament_id;

  update public.flpr_community_staging_log
  set tournament_id=v_tournament_id
  where id=v_stage_id;

  for v_row in
    select * from jsonb_array_elements(p_preview->'standings')
  loop
    v_name := trim(coalesce(v_row->>'name',''));
    if v_name='' then raise exception 'Standing contains an empty player name'; end if;
    v_player := null;

    -- Accept a trusted preview ID only when it still resolves to a live identity.
    if nullif(v_row->>'matchedPlayerId','') is not null then
      select id into v_player from public.players
      where id=(v_row->>'matchedPlayerId')::uuid and status<>'merged';
    end if;

    -- Resolve the central alias registry before creating a global identity.
    if v_player is null then
      v_alias_key := lower(regexp_replace(trim(v_name),'[^a-zA-Z0-9]+',' ','g'));
      select alias.canonical_player_id into v_player
      from public.flpr_player_aliases alias
      join public.players player on player.id=alias.canonical_player_id
      where alias.alias_key=v_alias_key and alias.is_active
        and player.status<>'merged'
      limit 1;
    end if;

    if v_player is null then
      select id into v_player from public.players
      where normalized_name=flpr.normalize_player_name(v_name)
        and status<>'merged'
      limit 1;
    end if;

    if v_player is null then
      v_slug := regexp_replace(
        lower(flpr.normalize_player_name(v_name)),'[^a-z0-9]+','-','g');
      v_slug := trim(both '-' from v_slug);
      insert into public.players(display_name,slug,provisional)
      values(v_name,v_slug,true)
      on conflict (normalized_name) where status<>'merged'
      do update set display_name=excluded.display_name
      returning id into v_player;
    end if;

    -- Global identity is shared; all competitive state remains community-owned.
    insert into public.flpr_community_memberships as membership(
      community_id,player_id,membership_status,local_display_name,created_by
    ) values (
      p_community_id,v_player,'active',v_name,auth.uid()
    )
    on conflict (community_id,player_id) do update set
      membership_status='active',
      local_display_name=coalesce(membership.local_display_name,
        excluded.local_display_name),
      updated_at=now();

    insert into public.tournament_players(
      tournament_id,player_id,source_player_name,identity_status,
      final_position,total_points,point_difference,wins,draws,losses,
      matches_played,is_champion
    ) values (
      v_tournament_id,v_player,v_name,
      case lower(trim(coalesce(v_row->>'matchStatus','')))
        when 'existing' then 'exact'
        when 'exact' then 'exact'
        when 'alias' then 'alias'
        when 'manual' then 'manual'
        else 'new'
      end,
      nullif(v_row->>'rank','')::integer,
      coalesce((v_row->>'points')::numeric,0),
      coalesce((v_row->>'diff')::numeric,0),
      coalesce((v_row->>'wins')::integer,0),
      coalesce((v_row->>'ties')::integer,0),
      coalesce((v_row->>'losses')::integer,0),
      coalesce((v_row->>'wins')::integer,0)
        +coalesce((v_row->>'ties')::integer,0)
        +coalesce((v_row->>'losses')::integer,0),
      coalesce((v_row->>'rank')::integer,999)=1
    );
  end loop;

  for v_match in
    select * from jsonb_array_elements(p_preview->'matches')
  loop
    insert into public.matches(
      tournament_id,round_number,court_label,match_number,
      team_a_score,team_b_score,status,raw_payload
    ) values (
      v_tournament_id,(v_match->>'round')::integer,v_match->>'court',0,
      (v_match->>'scoreA')::numeric,(v_match->>'scoreB')::numeric,
      case when coalesce((v_match->>'completed')::boolean,false)
        then 'completed' else 'scheduled' end,
      v_match
    ) returning id into v_match_id;

    for v_name in select value
      from jsonb_array_elements_text(v_match->'teamA')
    loop
      select player.id into v_tp
      from public.tournament_players player
      where player.tournament_id=v_tournament_id
        and player.source_player_key=flpr.normalize_player_name(v_name);
      if v_tp is null then
        raise exception 'Team A player % is not present in standings',v_name;
      end if;
      insert into public.match_players(
        match_id,tournament_player_id,team_no,team_slot,
        points_scored,points_conceded,result
      ) values (
        v_match_id,v_tp,1,
        case when not exists(select 1 from public.match_players
          where match_id=v_match_id and team_no=1) then 1 else 2 end,
        (v_match->>'scoreA')::numeric,(v_match->>'scoreB')::numeric,
        case when (v_match->>'scoreA')::numeric>(v_match->>'scoreB')::numeric then 'win'
          when (v_match->>'scoreA')::numeric<(v_match->>'scoreB')::numeric then 'loss'
          else 'draw' end
      );
    end loop;

    for v_name in select value
      from jsonb_array_elements_text(v_match->'teamB')
    loop
      select player.id into v_tp
      from public.tournament_players player
      where player.tournament_id=v_tournament_id
        and player.source_player_key=flpr.normalize_player_name(v_name);
      if v_tp is null then
        raise exception 'Team B player % is not present in standings',v_name;
      end if;
      insert into public.match_players(
        match_id,tournament_player_id,team_no,team_slot,
        points_scored,points_conceded,result
      ) values (
        v_match_id,v_tp,2,
        case when not exists(select 1 from public.match_players
          where match_id=v_match_id and team_no=2) then 1 else 2 end,
        (v_match->>'scoreB')::numeric,(v_match->>'scoreA')::numeric,
        case when (v_match->>'scoreB')::numeric>(v_match->>'scoreA')::numeric then 'win'
          when (v_match->>'scoreB')::numeric<(v_match->>'scoreA')::numeric then 'loss'
          else 'draw' end
      );
    end loop;
  end loop;

  if (select count(*) from public.tournament_players
      where tournament_id=v_tournament_id)<>v_standing_count then
    raise exception 'Staging validation failed: player row count mismatch';
  end if;
  if (select count(*) from public.matches
      where tournament_id=v_tournament_id)<>v_match_count then
    raise exception 'Staging validation failed: match row count mismatch';
  end if;
  if exists(
    select 1 from public.matches match_row
    where match_row.tournament_id=v_tournament_id
      and (select count(*) from public.match_players match_player
           where match_player.match_id=match_row.id)<>4
  ) then
    raise exception 'Staging validation failed: every match must have four players';
  end if;

  update public.flpr_community_staging_log
  set staging_status='verified',completed_at=now()
  where id=v_stage_id;

  return jsonb_build_object(
    'ok',true,'mode','private-staging','public',false,
    'communityId',p_community_id,'tournamentId',v_tournament_id,
    'stagingLogId',v_stage_id,'status','verified',
    'playersStaged',v_standing_count,'matchesStaged',v_match_count,
    'rankingsCalculated',false,'snapshotsCaptured',false
  );
end;
$$;

revoke all on function public.flpr_stage_community_tournament(uuid,jsonb)
  from public,anon;
grant execute on function public.flpr_stage_community_tournament(uuid,jsonb)
  to authenticated,service_role;

create or replace function public.flpr_discard_staged_community_tournament(
  p_community_id uuid,
  p_tournament_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_deleted uuid;
begin
  if not public.flpr_has_community_access(
    p_community_id,array['owner','admin']
  ) then
    raise exception 'Community Owner or Admin access required';
  end if;
  if not exists(select 1 from public.flpr_communities
    where id=p_community_id and status='inactive' and not is_default) then
    raise exception 'Discard requires an inactive, non-default community';
  end if;

  update public.flpr_community_staging_log
  set staging_status='discarded',completed_at=now()
  where community_id=p_community_id and tournament_id=p_tournament_id
    and staging_status='verified';

  delete from public.tournaments
  where id=p_tournament_id and community_id=p_community_id
    and status='verified'
  returning id into v_deleted;
  if v_deleted is null then raise exception 'Verified staged tournament not found'; end if;
  return true;
end;
$$;

revoke all on function public.flpr_discard_staged_community_tournament(uuid,uuid)
  from public,anon;
grant execute on function public.flpr_discard_staged_community_tournament(uuid,uuid)
  to authenticated,service_role;

create or replace function public.flpr_list_community_staging(
  p_community_id uuid
)
returns table(
  staging_log_id uuid,tournament_id uuid,tournament_name text,
  source_tournament_id text,staging_status text,player_count integer,
  match_count integer,created_at timestamptz,completed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.flpr_has_community_access(
    p_community_id,array['owner','admin','viewer']
  ) then raise exception 'Community access required'; end if;
  return query
  select log.id,log.tournament_id,tournament.name,
    log.source_tournament_id,log.staging_status,log.player_count,
    log.match_count,log.created_at,log.completed_at
  from public.flpr_community_staging_log log
  left join public.tournaments tournament on tournament.id=log.tournament_id
  where log.community_id=p_community_id
  order by log.created_at desc;
end;
$$;

revoke all on function public.flpr_list_community_staging(uuid)
  from public,anon;
grant execute on function public.flpr_list_community_staging(uuid)
  to authenticated,service_role;

comment on function public.flpr_stage_community_tournament(uuid,jsonb) is
  'Explicit inactive-community verified raw-data staging. Never calculates rankings or captures snapshots. Phase 5.5C-2.';
comment on function public.flpr_discard_staged_community_tournament(uuid,uuid) is
  'Discards only a verified staged tournament from an inactive non-default community. Phase 5.5C-2.';
comment on function public.flpr_list_community_staging(uuid) is
  'Private access-scoped staged-tournament inventory. Phase 5.5C-2.';

commit;

-- Post-install audit. Every result must be true.
with ids as (
  select
    (select id from public.flpr_communities where slug='jaksel') jaksel_id,
    (select id from public.flpr_communities where slug='jakut') jakut_id
),
legacy_commit as (
  select p.prosrc,md5(p.prosrc) function_hash
  from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='flpr_commit_tournament'
    and pg_get_function_identity_arguments(p.oid)='p_preview jsonb'
),
stage_function as (
  select p.prosrc,p.prosecdef
  from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='flpr_stage_community_tournament'
    and pg_get_function_identity_arguments(p.oid)
      ='p_community_id uuid, p_preview jsonb'
),
audit as (
  select 'staging_log_installed' audit_item,
    to_regclass('public.flpr_community_staging_log') is not null result,
    'private community-scoped audit trail' details
  union all
  select 'staging_log_rls_enabled',
    coalesce((select relrowsecurity from pg_catalog.pg_class
      where oid='public.flpr_community_staging_log'::regclass),false),
    'assigned-community read isolation'
  union all
  select 'scoped_stage_function_installed',exists(select 1 from stage_function),
    'explicit community_id transaction'
  union all
  select 'stage_function_is_security_definer',
    coalesce((select prosecdef from stage_function),false),
    'internal access check and atomic transaction'
  union all
  select 'stage_function_not_available_to_anon',
    not has_function_privilege('anon',
      'public.flpr_stage_community_tournament(uuid,jsonb)','EXECUTE'),
    'private Admin workflow'
  union all
  select 'stage_function_rejects_active_or_default_scope',
    coalesce((select prosrc like '%status<>''inactive''%'
      and prosrc like '%is_default%'
      from stage_function),false),
    'cannot be used on Jaksel'
  union all
  select 'stage_function_never_runs_global_calculation',
    coalesce((select prosrc not like '%flpr_recalculate_rankings%'
      and prosrc not like '%flpr_capture_ranking_snapshot%'
      and prosrc not like '%flpr_capture_championship_snapshot%'
      from stage_function),false),
    'verified raw data only'
  union all
  select 'discard_function_installed_and_private',
    to_regprocedure(
      'public.flpr_discard_staged_community_tournament(uuid,uuid)') is not null
    and not has_function_privilege('anon',
      'public.flpr_discard_staged_community_tournament(uuid,uuid)','EXECUTE'),
    'safe recovery before publish'
  union all
  select 'staging_inventory_installed_and_private',
    to_regprocedure('public.flpr_list_community_staging(uuid)') is not null
    and not has_function_privilege('anon',
      'public.flpr_list_community_staging(uuid)','EXECUTE'),
    'assigned Admin visibility only'
  union all
  select 'legacy_jaksel_commit_unchanged',
    coalesce((select function_hash='f64866b578f6be25b49a889b154460a0'
      from legacy_commit),false),
    coalesce((select 'hash '||function_hash from legacy_commit),'missing')
  union all
  select 'jaksel_v2_8_9_baseline_preserved',
    exists(select 1 from public.flpr_communities
      where slug='jaksel' and status='active' and is_default)
    and (select count(*)=21 from public.flpr_community_memberships m,ids
      where m.community_id=ids.jaksel_id and m.membership_status='active')
    and (select count(*)=21 from public.flpr_community_player_statistics s,ids
      where s.community_id=ids.jaksel_id)
    and (select count(*)=8 from public.tournaments t,ids
      where t.community_id=ids.jaksel_id and t.status='published'),
    '21 players / 21 statistics / 8 tournaments'
  union all
  select 'jakut_remains_inactive_empty_and_hidden',
    exists(select 1 from public.flpr_communities
      where slug='jakut' and status='inactive' and not is_default)
    and not exists(select 1 from public.flpr_community_memberships m,ids
      where m.community_id=ids.jakut_id)
    and not exists(select 1 from public.tournaments t,ids
      where t.community_id=ids.jakut_id)
    and not exists(select 1 from public.v_flpr_public_communities
      where slug='jakut'),
    'installer performs no staging or activation'
)
select audit_item,result,details from audit order by audit_item;

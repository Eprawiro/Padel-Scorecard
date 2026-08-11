-- FLPR Phase 5.5B-2M — V2 corrected
-- Read-only pre-install readiness audit for atomic scoped publish integration.

with ids as (
  select
    (select id from public.flpr_communities where slug='jaksel') jaksel_id,
    (select id from public.flpr_communities where slug='jakut') jakut_id
),
function_state as (
  select p.prosrc,p.prosecdef
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='flpr_commit_tournament'
    and pg_get_function_identity_arguments(p.oid)='p_preview jsonb'
),
audit as (
  select '01_jaksel_active_default' audit_item,
    exists(select 1 from public.flpr_communities
      where slug='jaksel' and status='active' and is_default) result,
    'Required publish target' details
  union all
  select '02_jakut_inactive_nondefault',
    exists(select 1 from public.flpr_communities
      where slug='jakut' and status='inactive' and not is_default),
    'Activation gate must remain closed'
  union all
  select '03_jakut_remains_empty',
    not exists(select 1 from public.flpr_community_memberships m,ids where m.community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_community_player_statistics s,ids where s.community_id=ids.jakut_id)
    and not exists(select 1 from public.tournaments t,ids where t.community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_community_ranking_history h,ids where h.community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_championship_ranking_history h,ids where h.community_id=ids.jakut_id),
    'No Jakut competitive data'
  union all
  select '04_commit_function_hash_preserved',
    coalesce((select md5(prosrc)='42a19c9a850b62ed4fd26124fe19444d' from function_state),false),
    coalesce((select md5(prosrc) from function_state),'missing')
  union all
  select '05_commit_security_definer',
    coalesce((select prosecdef from function_state),false),
    'Core publish privilege boundary'
  union all
  select '06_existing_atomic_steps_present',
    coalesce((select prosrc like '%flpr_recalculate_rankings%'
      and prosrc like '%flpr_capture_ranking_snapshot%'
      and prosrc like '%flpr_capture_championship_snapshot_v1%'
      from function_state),false),
    'Calculation + FLPR snapshot + Championship snapshot'
  union all
  select '07_direct_scoped_sync_not_yet_integrated',
    coalesce((select prosrc not like '%flpr_community_player_statistics%'
      from function_state),false),
    'Expected true before 5.5B-2M installation'
  union all
  select '08_safety_sync_trigger_enabled',exists(
    select 1 from pg_catalog.pg_trigger
    where tgname='flpr_sync_default_community_statistics'
      and not tgisinternal and tgenabled<>'D'),
    'Phase 5.5B-1H safety net'
  union all
  select '09_jaksel_membership_statistics_coverage',
    (select count(*) from public.flpr_community_memberships m,ids
      where m.community_id=ids.jaksel_id and m.membership_status='active')
    =
    (select count(*) from public.flpr_community_player_statistics s,ids
      where s.community_id=ids.jaksel_id),
    (select count(*)::text
     from public.flpr_community_memberships m
     where m.community_id=(select jaksel_id from ids)
       and m.membership_status='active')
    ||' active memberships / '||
    (select count(*)::text
     from public.flpr_community_player_statistics s
     where s.community_id=(select jaksel_id from ids))
    ||' statistics rows'
  union all
  select '10_jaksel_scoped_statistics_match_legacy',not exists(
    select 1
    from public.player_statistics legacy
    join public.flpr_community_memberships membership
      on membership.player_id=legacy.player_id
     and membership.community_id=(select jaksel_id from ids)
     and membership.membership_status='active'
    left join public.flpr_community_player_statistics scoped
      on scoped.community_id=membership.community_id
     and scoped.player_id=legacy.player_id
    where scoped.player_id is null
       or (to_jsonb(scoped)-'community_id'-'current_handicap'-'handicap_provisional')
          is distinct from to_jsonb(legacy)),
    'Required before atomic cutover'
  union all
  select '11_no_partial_published_tournaments',not exists(
    select 1 from public.tournaments t
    where t.community_id=(select jaksel_id from ids) and t.status='published'
      and (
        (select count(*) from public.tournament_players tp where tp.tournament_id=t.id)
          <> t.player_count
        or (select count(*) from public.matches m where m.tournament_id=t.id)
          <> t.match_count
      )),
    (select count(*)::text||' published Jaksel tournaments' from public.tournaments t
      where t.community_id=(select jaksel_id from ids) and t.status='published')
  union all
  select '12_michael_k_hotfix_preserved',exists(
    select 1 from public.v_flpr_public_community_players
    where community_slug='jaksel' and player_slug='michael-k'
      and rank=4 and tournaments_played=1 and matches_played=6
      and official_rating=65.3807 and player_status='PROVISIONAL'
      and ranking_eligible=false and photo_url is not null),
    'T8 newcomer regression guard'
)
select audit_item,result,details from audit order by audit_item;

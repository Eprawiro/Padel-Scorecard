-- FLPR Phase 5.5A-3H
-- FINAL PUBLIC ISOLATION AUDIT (READ ONLY)
-- Creates, changes, and deletes nothing.

with ids as (
  select
    (select id from public.flpr_communities where slug='jaksel' limit 1) jaksel_id,
    (select id from public.flpr_communities where slug='jakut' limit 1) jakut_id
), required_views(view_name) as (
  values
    ('v_flpr_public_communities'::text),
    ('v_flpr_public_community_players'),
    ('v_flpr_public_community_tournaments'),
    ('v_flpr_public_community_ranking_history'),
    ('v_flpr_public_community_rating_history'),
    ('v_flpr_public_community_handicap_history'),
    ('v_flpr_championship_ranking_v2'),
    ('v_flpr_championship_event_breakdown_v2'),
    ('v_flpr_community_relationship_live'),
    ('v_flpr_community_advanced_metrics_live'),
    ('v_flpr_community_ranking_history_timeline'),
    ('v_flpr_community_player_career_statistics'),
    ('v_flpr_community_player_analytics_dashboard')
), missing_views as (
  select view_name from required_views
  where to_regclass('public.'||view_name) is null
), missing_select_grants as (
  select role_name,view_name
  from (values('anon'::text),('authenticated'::text)) role(role_name)
  cross join required_views view
  where not exists(
    select 1 from information_schema.role_table_grants grant_info
    where grant_info.table_schema='public'
      and grant_info.table_name=view.view_name
      and grant_info.grantee=role.role_name
      and grant_info.privilege_type='SELECT')
), public_write_grants as (
  select grant_info.grantee,grant_info.table_name,grant_info.privilege_type
  from information_schema.role_table_grants grant_info
  join required_views view on view.view_name=grant_info.table_name
  where grant_info.table_schema='public'
    and grant_info.grantee in ('anon','authenticated')
    and grant_info.privilege_type<>'SELECT'
), scoped_rls as (
  select relation.relname,relation.relrowsecurity
  from pg_class relation
  join pg_namespace namespace on namespace.oid=relation.relnamespace
  where namespace.nspname='public'
    and relation.relname in (
      'flpr_community_memberships','flpr_community_player_statistics',
      'flpr_community_ranking_history','flpr_community_rating_history',
      'flpr_community_handicap_history','flpr_championship_ranking_history')
), audit as (
  select 'all_required_public_views_exist' audit_item,
    not exists(select 1 from missing_views) result,
    coalesce((select string_agg(view_name,', ' order by view_name) from missing_views),'none missing') details
  union all
  select 'anon_and_authenticated_have_select_on_all_views',
    not exists(select 1 from missing_select_grants),
    coalesce((select string_agg(role_name||':'||view_name,', ' order by role_name,view_name)
      from missing_select_grants),'all grants present')
  union all
  select 'public_views_have_no_write_grants',
    not exists(select 1 from public_write_grants),
    coalesce((select string_agg(grantee||':'||table_name||':'||privilege_type,', ')
      from public_write_grants),'SELECT only')
  union all
  select 'all_scoped_tables_have_rls',
    (select count(*)=6 and bool_and(relrowsecurity) from scoped_rls),
    (select count(*)::text||' scoped tables checked' from scoped_rls)
  union all
  select 'only_jaksel_is_active',
    (select count(*)=1 and bool_and(slug='jaksel') from public.flpr_communities where status='active'),
    (select string_agg(slug,',' order by slug) from public.flpr_communities where status='active')
  union all
  select 'public_registry_contains_only_jaksel',
    (select count(*)=1 and bool_and(slug='jaksel') from public.v_flpr_public_communities),
    (select string_agg(slug,',' order by slug) from public.v_flpr_public_communities)
  union all
  select 'jakut_remains_inactive',
    (select status='inactive' and not is_default from public.flpr_communities where slug='jakut'),
    (select status||case when is_default then ' default' else ' non-default' end
      from public.flpr_communities where slug='jakut')
  union all
  select 'jakut_base_scope_remains_empty',
    not exists(select 1 from public.flpr_community_memberships,ids where community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_community_player_statistics,ids where community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_community_ranking_history,ids where community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_championship_ranking_history,ids where community_id=ids.jakut_id)
    and not exists(select 1 from public.tournaments,ids where community_id=ids.jakut_id),
    'memberships, statistics, histories, and tournaments'
  union all
  select 'jakut_is_absent_from_all_public_scoped_views',
    not exists(select 1 from public.v_flpr_public_community_players where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_public_community_tournaments where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_public_community_ranking_history where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_public_community_rating_history where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_public_community_handicap_history where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_championship_ranking_v2 where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_championship_event_breakdown_v2 where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_community_relationship_live where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_community_advanced_metrics_live where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_community_ranking_history_timeline where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_community_player_career_statistics where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_community_player_analytics_dashboard where community_slug='jakut'),
    'zero Jakut rows across 12 scoped views'
  union all
  select 'jaksel_core_public_counts_are_preserved',
    (select count(*) from public.v_flpr_public_community_players where community_slug='jaksel')=20
    and (select count(*) from public.v_flpr_public_community_tournaments where community_slug='jaksel')=7
    and (select count(*) from public.v_flpr_public_community_ranking_history where community_slug='jaksel')=60,
    (select count(*)::text||' players / ' from public.v_flpr_public_community_players where community_slug='jaksel')
      ||(select count(*)::text||' tournaments / ' from public.v_flpr_public_community_tournaments where community_slug='jaksel')
      ||(select count(*)::text||' ranking-history rows' from public.v_flpr_public_community_ranking_history where community_slug='jaksel')
  union all
  select 'jaksel_championship_counts_are_preserved',
    (select count(*) from public.v_flpr_championship_ranking_v2 where community_slug='jaksel')=20
    and (select count(*) from public.v_flpr_championship_event_breakdown_v2 where community_slug='jaksel')=45,
    (select count(*)::text||' ranking / ' from public.v_flpr_championship_ranking_v2 where community_slug='jaksel')
      ||(select count(*)::text||' breakdown' from public.v_flpr_championship_event_breakdown_v2 where community_slug='jaksel')
  union all
  select 'jaksel_advanced_analytics_are_populated',
    exists(select 1 from public.v_flpr_community_relationship_live where community_slug='jaksel')
    and (select count(*) from public.v_flpr_community_advanced_metrics_live where community_slug='jaksel')=20,
    (select count(*)::text||' relationship rows / ' from public.v_flpr_community_relationship_live where community_slug='jaksel')
      ||(select count(*)::text||' advanced rows' from public.v_flpr_community_advanced_metrics_live where community_slug='jaksel')
  union all
  select 'jaksel_historical_analytics_are_complete',
    (select count(*) from public.v_flpr_community_ranking_history_timeline where community_slug='jaksel')=60
    and (select count(*) from public.v_flpr_community_player_career_statistics where community_slug='jaksel')=20
    and (select count(*) from public.v_flpr_community_player_analytics_dashboard where community_slug='jaksel')=20,
    (select count(*)::text||' timeline / ' from public.v_flpr_community_ranking_history_timeline where community_slug='jaksel')
      ||(select count(*)::text||' career / ' from public.v_flpr_community_player_career_statistics where community_slug='jaksel')
      ||(select count(*)::text||' dashboard' from public.v_flpr_community_player_analytics_dashboard where community_slug='jaksel')
  union all
  select 'legacy_jaksel_sources_are_preserved',
    (select count(*) from public.player_statistics)=20
    and (select count(*) from public.ranking_history)=60
    and to_regclass('public.v_flpr_relationship_live') is not null
    and to_regclass('public.v_flpr_advanced_metrics_live') is not null
    and to_regclass('public.v_flpr_ranking_history_timeline') is not null
    and to_regclass('public.v_flpr_player_analytics_dashboard') is not null,
    '20 legacy statistics / 60 legacy history / legacy views present'
)
select audit_item,result,details from audit order by audit_item;


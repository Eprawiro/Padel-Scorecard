-- FLPR Phase 5.5A-3H1
-- Public-view privilege hardening.
-- Changes grants only; changes no data, formulas, views, or RLS policies.

begin;

do $block$
declare
  view_name text;
begin
  foreach view_name in array array[
    'v_flpr_public_communities',
    'v_flpr_public_community_players',
    'v_flpr_public_community_tournaments',
    'v_flpr_public_community_ranking_history',
    'v_flpr_public_community_rating_history',
    'v_flpr_public_community_handicap_history',
    'v_flpr_championship_ranking_v2',
    'v_flpr_championship_event_breakdown_v2',
    'v_flpr_community_relationship_live',
    'v_flpr_community_advanced_metrics_live',
    'v_flpr_community_ranking_history_timeline',
    'v_flpr_community_player_career_statistics',
    'v_flpr_community_player_analytics_dashboard'
  ]
  loop
    execute format(
      'revoke all privileges on table public.%I from public, anon, authenticated',
      view_name
    );
    execute format(
      'grant select on table public.%I to anon, authenticated, service_role',
      view_name
    );
  end loop;
end
$block$;

commit;

-- Effective privilege audit. Every result must be true.
with required_views(view_name) as (
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
), effective_privileges as (
  select role_name,view_name,
    has_table_privilege(role_name,format('public.%I',view_name),'SELECT') can_select,
    has_table_privilege(role_name,format('public.%I',view_name),'INSERT') can_insert,
    has_table_privilege(role_name,format('public.%I',view_name),'UPDATE') can_update,
    has_table_privilege(role_name,format('public.%I',view_name),'DELETE') can_delete,
    has_table_privilege(role_name,format('public.%I',view_name),'TRUNCATE') can_truncate,
    has_table_privilege(role_name,format('public.%I',view_name),'REFERENCES') can_reference,
    has_table_privilege(role_name,format('public.%I',view_name),'TRIGGER') can_trigger
  from (values('anon'::text),('authenticated'::text)) role(role_name)
  cross join required_views
), audit as (
  select 'anon_has_select_on_all_13_views' audit_item,
    count(*) filter (where role_name='anon')=13
      and (bool_and(can_select) filter (where role_name='anon')) result
  from effective_privileges
  union all
  select 'authenticated_has_select_on_all_13_views',
    count(*) filter (where role_name='authenticated')=13
      and (bool_and(can_select) filter (where role_name='authenticated'))
  from effective_privileges
  union all
  select 'anon_has_no_write_privileges',
    not (bool_or(can_insert or can_update or can_delete or can_truncate or can_reference or can_trigger)
      filter (where role_name='anon'))
  from effective_privileges
  union all
  select 'authenticated_has_no_write_privileges',
    not (bool_or(can_insert or can_update or can_delete or can_truncate or can_reference or can_trigger)
      filter (where role_name='authenticated'))
  from effective_privileges
  union all
  select 'jaksel_public_data_remains_available',
    (select count(*) from public.v_flpr_public_community_players where community_slug='jaksel')=20
    and (select count(*) from public.v_flpr_public_community_tournaments where community_slug='jaksel')=7
    and (select count(*) from public.v_flpr_community_player_analytics_dashboard where community_slug='jaksel')=20
  union all
  select 'jakut_remains_absent_from_public_views',
    not exists(select 1 from public.v_flpr_public_communities where slug='jakut')
    and not exists(select 1 from public.v_flpr_public_community_players where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_community_player_analytics_dashboard where community_slug='jakut')
)
select audit_item,result from audit order by audit_item;

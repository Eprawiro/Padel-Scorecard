-- FLPR Phase 5.5A-3F-A
-- READ ONLY: historical analytics community-scope readiness audit.

with ids as (
  select
    (select id from public.flpr_communities where slug='jaksel' limit 1) jaksel_id,
    (select id from public.flpr_communities where slug='jakut' limit 1) jakut_id
), audit as (
  select 'legacy_dashboard_view_exists' audit_item,
    to_regclass('public.v_flpr_player_analytics_dashboard') is not null result,
    'v_flpr_player_analytics_dashboard' details
  union all
  select 'legacy_timeline_view_exists',
    to_regclass('public.v_flpr_ranking_history_timeline') is not null,
    'v_flpr_ranking_history_timeline'
  union all
  select 'legacy_dashboard_contains_20_players',
    (select count(*) from public.v_flpr_player_analytics_dashboard)=20,
    (select count(*)::text||' dashboard rows' from public.v_flpr_player_analytics_dashboard)
  union all
  select 'legacy_timeline_contains_60_rows',
    (select count(*) from public.v_flpr_ranking_history_timeline)=60,
    (select count(*)::text||' timeline rows' from public.v_flpr_ranking_history_timeline)
  union all
  select 'jaksel_scoped_history_contains_60_rows',
    (select count(*) from public.flpr_community_ranking_history h,ids
      where h.community_id=ids.jaksel_id)=60,
    (select count(*)::text||' Jaksel scoped rows'
      from public.flpr_community_ranking_history h,ids
      where h.community_id=ids.jaksel_id)
  union all
  select 'jaksel_scoped_history_matches_legacy',not exists(
    select 1
    from public.ranking_history old
    full join public.flpr_community_ranking_history scoped
      on scoped.community_id=(select jaksel_id from ids)
     and scoped.snapshot_key=old.snapshot_key and scoped.player_id=old.player_id
    where old.player_id is null or scoped.player_id is null
       or (to_jsonb(scoped)-'id'-'community_id'-'legacy_ranking_history_id')
          is distinct from (to_jsonb(old)-'id')),
    'Exact history content parity excluding scoped identity columns'
  union all
  select 'jakut_scoped_history_is_empty',not exists(
    select 1 from public.flpr_community_ranking_history h,ids
    where h.community_id=ids.jakut_id),
    (select count(*)::text||' Jakut rows'
      from public.flpr_community_ranking_history h,ids
      where h.community_id=ids.jakut_id)
  union all
  select 'jakut_remains_inactive',
    (select status='inactive' from public.flpr_communities where slug='jakut'),
    (select status from public.flpr_communities where slug='jakut')
  union all
  select 'only_jaksel_is_publicly_selectable',
    (select count(*)=1 and bool_and(slug='jaksel') from public.v_flpr_public_communities),
    (select string_agg(slug,',' order by slug) from public.v_flpr_public_communities)
)
select audit_item,result,details from audit order by audit_item;

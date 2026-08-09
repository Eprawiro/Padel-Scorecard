-- FLPR Phase 5.5A-3A
-- Community-scoped public data readiness audit (READ ONLY)
-- Creates, changes, and deletes nothing.

with
community_ids as (
  select
    (select id from public.flpr_communities where slug = 'jaksel' limit 1) as jaksel_id,
    (select id from public.flpr_communities where slug = 'jakut' limit 1) as jakut_id
),
counts as (
  select
    (select count(*) from public.flpr_communities) as community_count,
    (select count(*) from public.flpr_communities where status = 'active') as active_community_count,
    (select count(*) from public.v_flpr_public_communities) as public_community_count,
    (select count(*) from public.flpr_community_memberships m, community_ids c
      where m.community_id = c.jaksel_id and m.membership_status = 'active') as jaksel_members,
    (select count(*) from public.flpr_community_player_statistics s, community_ids c
      where s.community_id = c.jaksel_id) as jaksel_statistics,
    (select count(*) from public.tournaments t, community_ids c
      where t.community_id = c.jaksel_id and t.status = 'published') as jaksel_tournaments,
    (select count(*) from public.flpr_community_ranking_history h, community_ids c
      where h.community_id = c.jaksel_id) as jaksel_ranking_history,
    (select count(*) from public.flpr_community_rating_history h, community_ids c
      where h.community_id = c.jaksel_id) as jaksel_rating_history,
    (select count(*) from public.flpr_community_handicap_history h, community_ids c
      where h.community_id = c.jaksel_id) as jaksel_handicap_history,
    (select count(*) from public.flpr_championship_ranking_history h, community_ids c
      where h.community_id = c.jaksel_id) as jaksel_championship_history,
    (select count(*) from public.flpr_community_memberships m, community_ids c
      where m.community_id = c.jakut_id) as jakut_members,
    (select count(*) from public.flpr_community_player_statistics s, community_ids c
      where s.community_id = c.jakut_id) as jakut_statistics,
    (select count(*) from public.tournaments t, community_ids c
      where t.community_id = c.jakut_id) as jakut_tournaments,
    (select count(*) from public.flpr_community_ranking_history h, community_ids c
      where h.community_id = c.jakut_id) as jakut_ranking_history,
    (select count(*) from public.flpr_championship_ranking_history h, community_ids c
      where h.community_id = c.jakut_id) as jakut_championship_history,
    (select count(*) from public.player_statistics) as legacy_statistics,
    (select count(*) from public.ranking_history) as legacy_ranking_history,
    (select count(*) from public.rating_history) as legacy_rating_history,
    (select count(*) from public.handicap_history) as legacy_handicap_history
),
statistics_mismatches as (
  select count(*) as mismatch_count
  from public.player_statistics legacy
  full join public.flpr_community_player_statistics scoped
    on scoped.player_id = legacy.player_id
   and scoped.community_id = (select jaksel_id from community_ids)
  where legacy.player_id is null
     or scoped.player_id is null
     or (to_jsonb(scoped) - 'community_id') is distinct from to_jsonb(legacy)
),
view_state as (
  select
    coalesce((select view_definition ilike '%8f4c2b6e-7d91-4a53-9c20-000000000001%'
      from information_schema.views
      where table_schema='public' and table_name='v_flpr_championship_ranking_v1'),false)
      as championship_ranking_hardcoded_to_jaksel,
    coalesce((select view_definition ilike '%8f4c2b6e-7d91-4a53-9c20-000000000001%'
      from information_schema.views
      where table_schema='public' and table_name='v_flpr_championship_event_breakdown_v1'),false)
      as championship_breakdown_hardcoded_to_jaksel,
    exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name='v_flpr_championship_ranking_v1'
        and column_name='community_id'
    ) as championship_ranking_exposes_community_id
),
audit as (
  select 'community_count_is_two' audit_item,
         c.community_count = 2 result,
         c.community_count::text || ' communities' details from counts c
  union all
  select 'only_jaksel_is_active', c.active_community_count = 1,
         c.active_community_count::text || ' active community' from counts c
  union all
  select 'public_registry_contains_only_jaksel',
         c.public_community_count = 1
           and exists(select 1 from public.v_flpr_public_communities where slug='jaksel')
           and not exists(select 1 from public.v_flpr_public_communities where slug='jakut'),
         c.public_community_count::text || ' publicly selectable community' from counts c
  union all
  select 'jaksel_remains_default_active',
         exists(select 1 from public.flpr_communities where slug='jaksel' and status='active' and is_default),
         'Jaksel must remain active/default' from counts c
  union all
  select 'jakut_exists_inactive',
         exists(select 1 from public.flpr_communities where slug='jakut' and status='inactive' and not is_default),
         'Jakut must remain inactive/non-default' from counts c
  union all
  select 'jaksel_has_20_active_members', c.jaksel_members = 20,
         c.jaksel_members::text || ' active members' from counts c
  union all
  select 'jaksel_has_7_published_tournaments', c.jaksel_tournaments = 7,
         c.jaksel_tournaments::text || ' published tournaments' from counts c
  union all
  select 'jaksel_statistics_has_20_rows', c.jaksel_statistics = 20,
         c.jaksel_statistics::text || ' scoped rows' from counts c
  union all
  select 'jaksel_statistics_matches_legacy', m.mismatch_count = 0,
         m.mismatch_count::text || ' content mismatches' from statistics_mismatches m
  union all
  select 'jaksel_ranking_history_matches_legacy_count',
         c.jaksel_ranking_history = c.legacy_ranking_history,
         c.jaksel_ranking_history::text || ' scoped / ' || c.legacy_ranking_history::text || ' legacy rows' from counts c
  union all
  select 'jaksel_rating_history_matches_legacy_count',
         c.jaksel_rating_history = c.legacy_rating_history,
         c.jaksel_rating_history::text || ' scoped / ' || c.legacy_rating_history::text || ' legacy rows' from counts c
  union all
  select 'jaksel_handicap_history_matches_legacy_count',
         c.jaksel_handicap_history = c.legacy_handicap_history,
         c.jaksel_handicap_history::text || ' scoped / ' || c.legacy_handicap_history::text || ' legacy rows' from counts c
  union all
  select 'jaksel_championship_history_has_baseline',
         c.jaksel_championship_history >= 20,
         c.jaksel_championship_history::text || ' Championship history rows' from counts c
  union all
  select 'jakut_starts_completely_empty',
         c.jakut_members=0 and c.jakut_statistics=0 and c.jakut_tournaments=0
           and c.jakut_ranking_history=0 and c.jakut_championship_history=0,
         concat('members ',c.jakut_members,', statistics ',c.jakut_statistics,
           ', tournaments ',c.jakut_tournaments,', ranking history ',c.jakut_ranking_history,
           ', Championship history ',c.jakut_championship_history) from counts c
  union all
  select 'championship_ranking_is_still_jaksel_v1',
         v.championship_ranking_hardcoded_to_jaksel,
         'Expected before Phase 5.5A-3 scoped replacement' from view_state v
  union all
  select 'championship_breakdown_is_still_jaksel_v1',
         v.championship_breakdown_hardcoded_to_jaksel,
         'Expected before Phase 5.5A-3 scoped replacement' from view_state v
  union all
  select 'championship_v1_does_not_expose_community_id',
         not v.championship_ranking_exposes_community_id,
         'Expected before Phase 5.5A-3 scoped replacement' from view_state v
  union all
  select 'community_statistics_rls_enabled', c.relrowsecurity,
         'flpr_community_player_statistics' from pg_class c
         join pg_namespace n on n.oid=c.relnamespace
         where n.nspname='public' and c.relname='flpr_community_player_statistics'
  union all
  select 'community_history_rls_enabled', c.relrowsecurity,
         'flpr_community_ranking_history' from pg_class c
         join pg_namespace n on n.oid=c.relnamespace
         where n.nspname='public' and c.relname='flpr_community_ranking_history'
)
select audit_item,result,details
from audit
order by audit_item;

-- FLPR Phase 5.5C-2
-- INACTIVE-COMMUNITY SCOPED STAGING — PRE-INSTALL AUDIT
-- READ ONLY: creates, changes, and deletes nothing.
--
-- This audit fingerprints the legacy/default-community publisher and proves
-- the isolation boundary required before a separate scoped staging publisher
-- is added. Expected result before installation: every row is true.

with
ids as (
  select
    (select id from public.flpr_communities where slug='jaksel' limit 1) jaksel_id,
    (select id from public.flpr_communities where slug='jakut' limit 1) jakut_id
),
function_state as (
  select p.proname,pg_get_function_identity_arguments(p.oid) arguments,
    p.prosrc,p.prosecdef,md5(p.prosrc) function_hash,
    pg_get_function_result(p.oid) result_type
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname in (
      'flpr_commit_tournament','flpr_recalculate_rankings',
      'flpr_capture_ranking_snapshot',
      'flpr_capture_championship_snapshot_v1',
      'flpr_get_community_activation_readiness',
      'flpr_stage_community_tournament'
    )
),
commit_function as (
  select * from function_state
  where proname='flpr_commit_tournament' and arguments='p_preview jsonb'
),
recalculate_function as (
  select * from function_state
  where proname='flpr_recalculate_rankings' and arguments=''
),
ranking_snapshot_function as (
  select * from function_state
  where proname='flpr_capture_ranking_snapshot'
),
championship_snapshot_function as (
  select * from function_state
  where proname='flpr_capture_championship_snapshot_v1'
),
tournament_status_constraints as (
  select pg_get_constraintdef(constraint_row.oid) definition
  from pg_catalog.pg_constraint constraint_row
  where constraint_row.conrelid='public.tournaments'::regclass
    and constraint_row.contype='c'
    and pg_get_constraintdef(constraint_row.oid) ilike '%status%'
),
tournament_community_column as (
  select column_default,is_nullable
  from information_schema.columns
  where table_schema='public' and table_name='tournaments'
    and column_name='community_id'
),
audit as (
  select '01_5_5c1_readiness_gate_preserved'::text audit_item,
    to_regprocedure(
      'public.flpr_get_community_activation_readiness(uuid)') is not null
    and exists(
      select 1 from function_state
      where proname='flpr_get_community_activation_readiness'
        and prosecdef
    ) result,
    'activation remains fail-closed'::text details

  union all
  select '02_jaksel_v2_8_9_baseline_preserved',
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
  select '03_jakut_inactive_nondefault',
    exists(select 1 from public.flpr_communities
      where slug='jakut' and status='inactive' and not is_default),
    'staging target remains private'

  union all
  select '04_jakut_competitive_scope_still_empty',
    not exists(select 1 from public.flpr_community_memberships m,ids
      where m.community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_community_player_statistics s,ids
      where s.community_id=ids.jakut_id)
    and not exists(select 1 from public.tournaments t,ids
      where t.community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_community_ranking_history h,ids
      where h.community_id=ids.jakut_id)
    and not exists(select 1 from public.flpr_championship_ranking_history h,ids
      where h.community_id=ids.jakut_id),
    'no staging writes have started'

  union all
  select '05_legacy_commit_fingerprint_captured',
    exists(select 1 from commit_function),
    coalesce((select 'hash '||function_hash from commit_function),'missing')

  union all
  select '06_legacy_commit_atomic_steps_preserved',
    coalesce((select prosrc like '%flpr_recalculate_rankings%'
      and prosrc like '%flpr_sync_default_community_statistics_now%'
      and prosrc like '%flpr_capture_ranking_snapshot%'
      and prosrc like '%flpr_sync_default_community_ranking_history_now%'
      and prosrc like '%flpr_capture_championship_snapshot_v1%'
      from commit_function),false),
    'existing Jaksel publisher remains unchanged'

  union all
  select '07_legacy_commit_is_service_role_only',
    coalesce((select prosecdef from commit_function),false)
    and has_function_privilege('service_role',
      'public.flpr_commit_tournament(jsonb)','EXECUTE')
    and not has_function_privilege('anon',
      'public.flpr_commit_tournament(jsonb)','EXECUTE')
    and not has_function_privilege('authenticated',
      'public.flpr_commit_tournament(jsonb)','EXECUTE'),
    'no browser role can publish directly'

  union all
  select '08_legacy_commit_uses_implicit_community_default',
    coalesce((select
      prosrc !~* 'insert[[:space:]]+into[[:space:]]+public[.]tournaments[[:space:]]*[(][^)]*community_id'
      and prosrc like '%returning id, community_id%'
      from commit_function),false),
    'reason a separate explicit-community staging publisher is required'

  union all
  select '09_global_recalculator_fingerprint_captured',
    exists(select 1 from recalculate_function),
    coalesce((select 'hash '||function_hash from recalculate_function),'missing')

  union all
  select '10_current_recalculator_is_zero_argument_global',
    exists(select 1 from recalculate_function)
    and coalesce((select prosrc not ilike '%community_id%'
      from recalculate_function),false),
    'must not be reused for inactive-community staging'

  union all
  select '11_legacy_ranking_snapshot_fingerprint_captured',
    exists(select 1 from ranking_snapshot_function),
    coalesce((select string_agg(arguments||' · '||function_hash,', ' order by arguments)
      from ranking_snapshot_function),'missing')

  union all
  select '12_championship_snapshot_fingerprint_captured',
    exists(select 1 from championship_snapshot_function),
    coalesce((select string_agg(arguments||' · '||function_hash,', ' order by arguments)
      from championship_snapshot_function),'missing')

  union all
  select '13_tournament_community_column_is_required',
    exists(select 1 from tournament_community_column
      where is_nullable='NO'),
    coalesce((select 'default '||coalesce(column_default,'none')
      from tournament_community_column),'column missing')

  union all
  select '14_tournament_status_constraint_discovered',
    exists(select 1 from tournament_status_constraints),
    coalesce((select string_agg(definition,'; ' order by definition)
      from tournament_status_constraints),'missing')

  union all
  select '15_scoped_staging_publisher_not_yet_installed',
    to_regprocedure(
      'public.flpr_stage_community_tournament(uuid,jsonb)') is null,
    'expected before Phase 5.5C-2 installation'

  union all
  select '16_assigned_admin_can_manage_memberships',
    to_regprocedure(
      'public.flpr_set_community_membership(uuid,uuid,text,text)') is not null
    and has_function_privilege('authenticated',
      'public.flpr_set_community_membership(uuid,uuid,text,text)','EXECUTE')
    and not has_function_privilege('anon',
      'public.flpr_set_community_membership(uuid,uuid,text,text)','EXECUTE'),
    'player preparation path exists and remains access-scoped'

  union all
  select '17_inactive_community_is_publicly_hidden',
    not exists(select 1 from public.v_flpr_public_communities
      where slug='jakut')
    and not exists(select 1 from public.v_flpr_public_community_players
      where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_public_community_tournaments
      where community_slug='jakut'),
    'staged data will remain private before activation'

  union all
  select '18_jakut_has_active_owner_or_admin',
    exists(select 1
      from public.flpr_admin_community_access access
      join public.flpr_admin_users admin_user
        on admin_user.user_id=access.user_id
      cross join ids
      where access.community_id=ids.jakut_id
        and access.active and admin_user.active
        and access.community_role in ('owner','admin')),
    'authorized staging operator exists'
)
select audit_item,result,details
from audit
order by audit_item;


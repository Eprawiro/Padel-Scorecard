-- FLPR Phase 5.4D final post-install audit (READ ONLY)

with commit_function as (
  select p.prosrc, p.prosecdef
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'flpr_commit_tournament'
    and p.prokind = 'f'
    and p.pronargs = 1
),
audit as (
  select 'atomic_commit_installed'::text as audit_item,
    exists (
      select 1 from commit_function
      where prosrc like '%flpr_capture_championship_snapshot_v1%'
        and prosrc like '%''tournament_publish''%'
    ) as result,
    'Championship capture is inside flpr_commit_tournament'::text as details
  union all
  select 'community_membership_is_transactional',
    exists (select 1 from commit_function
      where prosrc like '%insert into public.flpr_community_memberships%'),
    'Participants are attached to the tournament community before capture'
  union all
  select 'existing_flpr_snapshot_is_preserved',
    exists (select 1 from commit_function
      where prosrc like '%flpr_capture_ranking_snapshot%'),
    'Existing FLPR snapshot call remains in the commit transaction'
  union all
  select 'flpr_history_has_three_valid_snapshots',
    (select count(*) = 60 and count(distinct snapshot_key) = 3
      from public.ranking_history),
    (select count(*)::text || ' rows / ' || count(distinct snapshot_key)::text || ' snapshots'
      from public.ranking_history)
  union all
  select 'flpr_snapshot_groups_are_complete',
    not exists (
      select 1
      from public.ranking_history
      group by snapshot_key
      having count(*) <> 20
    ),
    'Every stored FLPR snapshot contains 20 player rows'
  union all
  select 't7_championship_baseline_is_preserved',
    (select count(*) = 20
      from public.flpr_championship_ranking_history
      where snapshot_source = 'manual_baseline'
        and snapshot_key = 'championship-v1:695e410d-61a7-44f3-9a3b-db5c06cd4a1b'),
    '20 T7 Championship baseline rows'
  union all
  select 'no_championship_trigger_enabled',
    not exists (
      select 1
      from pg_catalog.pg_trigger trigger
      join pg_catalog.pg_proc function on function.oid = trigger.tgfoid
      where not trigger.tgisinternal
        and (trigger.tgname ilike '%championship%'
          or function.proname ilike '%championship%')
    ),
    'Championship capture is transaction-call only, not trigger-driven'
  union all
  select 'service_role_only_commit',
    has_function_privilege('service_role',
      'public.flpr_commit_tournament(jsonb)', 'EXECUTE')
    and not has_function_privilege('anon',
      'public.flpr_commit_tournament(jsonb)', 'EXECUTE')
    and not has_function_privilege('authenticated',
      'public.flpr_commit_tournament(jsonb)', 'EXECUTE'),
    'Commit remains restricted to service_role'
)
select audit_item, result, details
from audit
order by audit_item;


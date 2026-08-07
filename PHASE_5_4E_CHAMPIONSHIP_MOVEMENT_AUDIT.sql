-- FLPR Phase 5.4E — read-only Championship movement audit
-- Creates, changes, and deletes nothing.

with snapshot_summary as (
  select
    count(distinct snapshot_key) as snapshot_count,
    count(*) as history_rows,
    count(*) filter (where previous_rank is not null) as comparable_rows
  from public.flpr_championship_ranking_history
  where calculation_version = 'championship-v1'
), current_summary as (
  select count(*) as current_rows
  from public.v_flpr_championship_ranking_v1
), audit as (
  select 'current_view_contains_20_players' as audit_item,
         (select current_rows = 20 from current_summary) as result
  union all
  select 'history_contains_complete_snapshots',
         history_rows = snapshot_count * 20
  from snapshot_summary
  union all
  select 't7_baseline_is_not_fake_movement',
         snapshot_count <> 1 or comparable_rows = 0
  from snapshot_summary
  union all
  select 'movement_ready_only_after_second_snapshot',
         (snapshot_count < 2 and comparable_rows = 0)
         or (snapshot_count >= 2 and comparable_rows > 0)
  from snapshot_summary
)
select audit_item, result
from audit
order by audit_item;

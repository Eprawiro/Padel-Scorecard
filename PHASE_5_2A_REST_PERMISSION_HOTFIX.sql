-- FLPR Phase 5.2A — REST permission hotfix
-- Fixes zero/fallback advanced metrics in the public frontend.

begin;

drop view if exists public.v_flpr_advanced_metrics_live;

create view public.v_flpr_advanced_metrics_live
with (security_barrier = true)
as
select *
from public.v_flpr_advanced_metric_preview;

grant select on public.v_flpr_advanced_metrics_live to anon, authenticated;

comment on view public.v_flpr_advanced_metrics_live is
'Public read-only FLPR analytics projection. Owner execution permits REST access without exposing source-table write access.';

commit;

select
  count(*) as covered_players,
  count(proposed_clutch) as players_with_clutch_evidence,
  count(*) filter (where proposed_schedule_strength is not null) as players_with_schedule,
  count(*) filter (where proposed_versatility is not null) as players_with_versatility
from public.v_flpr_advanced_metrics_live;

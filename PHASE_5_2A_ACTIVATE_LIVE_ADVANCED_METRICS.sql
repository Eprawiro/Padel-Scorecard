-- FLPR Phase 5.2A — Activate validated dynamic advanced metrics
-- Depends on v_flpr_advanced_metric_preview revision 2.

begin;

drop view if exists public.v_flpr_advanced_metrics_live;

create view public.v_flpr_advanced_metrics_live
with (security_invoker = true)
as
select *
from public.v_flpr_advanced_metric_preview;

grant select on public.v_flpr_advanced_metrics_live to anon, authenticated;

commit;

select
  count(*) as covered_players,
  count(proposed_clutch) as players_with_clutch_evidence,
  count(*) filter (where proposed_schedule_strength is not null) as players_with_schedule,
  count(*) filter (where proposed_versatility is not null) as players_with_versatility
from public.v_flpr_advanced_metrics_live;

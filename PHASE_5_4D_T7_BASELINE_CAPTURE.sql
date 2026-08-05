-- FLPR Phase 5.4D — One-time T7 Championship Ranking baseline capture
-- WRITES exactly one protected baseline snapshot set (20 player rows).
-- Safe to rerun: duplicate rows are skipped by the capture function.

begin;

do $$
declare
  v_inserted integer;
  v_skipped integer;
  v_key text;
  v_total integer;
begin
  select capture.inserted_count, capture.skipped_count, capture.captured_snapshot_key
  into v_inserted, v_skipped, v_key
  from public.flpr_capture_championship_snapshot_v1(
    '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid,
    '695e410d-61a7-44f3-9a3b-db5c06cd4a1b'::uuid,
    'manual_baseline'
  ) capture;

  if not (
    (v_inserted = 20 and v_skipped = 0)
    or (v_inserted = 0 and v_skipped = 20)
  ) then
    raise exception 'Unexpected capture result: inserted %, skipped %, key %',
      v_inserted, v_skipped, v_key;
  end if;

  select count(*)::integer
  into v_total
  from public.flpr_championship_ranking_history
  where community_id = '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid
    and tournament_id = '695e410d-61a7-44f3-9a3b-db5c06cd4a1b'::uuid
    and calculation_version = 'championship-v1';

  if v_total <> 20 then
    raise exception 'Baseline capture rollback: expected 20 stored rows, found %', v_total;
  end if;
end
$$;

commit;

-- Post-capture and idempotency audit. Expected: every result is true.
with
config as (
  select
    '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid as community_id,
    '695e410d-61a7-44f3-9a3b-db5c06cd4a1b'::uuid as tournament_id
),
idempotency_rerun as materialized (
  select *
  from public.flpr_capture_championship_snapshot_v1(
    '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid,
    '695e410d-61a7-44f3-9a3b-db5c06cd4a1b'::uuid,
    'manual_baseline'
  )
),
baseline as (
  select history.*
  from public.flpr_championship_ranking_history history
  cross join config c
  where history.community_id = c.community_id
    and history.tournament_id = c.tournament_id
    and history.calculation_version = 'championship-v1'
),
audit as (
  select 'baseline_contains_20_rows'::text as audit_item,
    count(*) = 20 as result,
    format('%s stored rows', count(*)) as details
  from baseline
  union all
  select 'baseline_players_are_unique', count(*) = count(distinct player_id),
    format('%s rows / %s players', count(*), count(distinct player_id)) from baseline
  union all
  select 'baseline_ranks_are_1_to_20', min(championship_rank) = 1
      and max(championship_rank) = 20
      and count(distinct championship_rank) = 20,
    format('rank %s to %s; %s unique', min(championship_rank), max(championship_rank), count(distinct championship_rank))
    from baseline
  union all
  select 'baseline_previous_values_are_null',
    count(*) filter (where previous_rank is not null or rank_movement is not null
      or previous_score is not null or score_change is not null) = 0,
    format('%s rows with previous values', count(*) filter (
      where previous_rank is not null or rank_movement is not null
        or previous_score is not null or score_change is not null))
    from baseline
  union all
  select 'baseline_source_is_manual_baseline',
    count(*) filter (where snapshot_source <> 'manual_baseline') = 0,
    format('%s source mismatches', count(*) filter (where snapshot_source <> 'manual_baseline'))
    from baseline
  union all
  select 'baseline_snapshot_key_is_stable', count(distinct snapshot_key) = 1
      and min(snapshot_key) = 'championship-v1:695e410d-61a7-44f3-9a3b-db5c06cd4a1b',
    min(snapshot_key) from baseline
  union all
  select 'baseline_matches_current_ranking', count(*) = 20,
    format('%s exact player/rank/score matches', count(*))
    from baseline history
    join public.v_flpr_championship_ranking_v1 ranking
      on ranking.player_id = history.player_id
      and ranking.championship_rank = history.championship_rank
      and abs(ranking.championship_score - history.championship_score) <= 0.01
  union all
  select 'eligibility_distribution_matches',
    count(*) filter (where championship_eligibility = 'ELIGIBLE') = 2
      and count(*) filter (where championship_eligibility = 'EMERGING') = 4
      and count(*) filter (where championship_eligibility = 'PROVISIONAL') = 14,
    format('eligible %s; emerging %s; provisional %s',
      count(*) filter (where championship_eligibility = 'ELIGIBLE'),
      count(*) filter (where championship_eligibility = 'EMERGING'),
      count(*) filter (where championship_eligibility = 'PROVISIONAL'))
    from baseline
  union all
  select 'idempotent_rerun_skipped_all', inserted_count = 0 and skipped_count = 20,
    format('inserted %s; skipped %s', inserted_count, skipped_count)
    from idempotency_rerun
  union all
  select 'no_capture_trigger_enabled',
    not exists (
      select 1 from pg_trigger tr
      join pg_class cl on cl.oid = tr.tgrelid
      join pg_namespace ns on ns.oid = cl.relnamespace
      where ns.nspname = 'public'
        and not tr.tgisinternal
        and (tr.tgname ilike '%championship%' or pg_get_triggerdef(tr.oid) ilike '%championship%')
    ), 'No automatic Championship trigger'
  union all
  select 'existing_flpr_history_preserved',
    (select count(*) = 40 from public.flpr_community_ranking_history),
    format('%s existing FLPR history rows', (select count(*) from public.flpr_community_ranking_history))
)
select audit_item, result, details
from audit
order by audit_item;

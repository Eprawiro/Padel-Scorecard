-- FLPR Phase 5.4B — Championship Ranking v1 shadow view activation
-- READ ONLY: creates a computed view; no production rank, rating, statistics,
-- tournament, or history row is inserted, updated, or deleted.

drop view if exists public.v_flpr_championship_ranking_v1;

create view public.v_flpr_championship_ranking_v1
with (security_invoker = true)
as

with
params as (
  select
    '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid as community_id,
    8::integer as rolling_tournament_window,
    1.0::numeric as participation_points,
    10.0::numeric as champion_bonus,
    7.0::numeric as runner_up_bonus,
    5.0::numeric as third_place_bonus,
    3.0::numeric as top_50_bonus,
    1.0::numeric as top_70_bonus,
    8.0::numeric as standard_field_size,
    0.85::numeric as field_multiplier_floor,
    1.35::numeric as field_multiplier_ceiling,
    90::integer as inactivity_grace_days,
    0.05::numeric as decay_per_30_days,
    0.30::numeric as maximum_decay
),
community_tournaments as (
  select
    t.id,
    t.name,
    coalesce(t.tournament_date, t.published_at::date, t.imported_at::date, t.created_at::date) as event_date,
    row_number() over (
      order by
        coalesce(t.tournament_date, t.published_at::date, t.imported_at::date, t.created_at::date) desc,
        t.id desc
    ) as recency_number
  from public.tournaments t
  cross join params p
  where t.community_id = p.community_id
    and t.status = 'published'
),
rolling_tournaments as (
  select ct.*
  from community_tournaments ct
  cross join params p
  where ct.recency_number <= p.rolling_tournament_window
),
verified_entries as (
  select
    rt.id as tournament_id,
    rt.name as tournament_name,
    rt.event_date,
    rt.recency_number,
    tp.player_id,
    tp.final_position,
    count(*) over (partition by rt.id)::integer as field_size
  from rolling_tournaments rt
  join public.tournament_players tp
    on tp.tournament_id = rt.id
  where tp.player_id is not null
    and tp.final_position is not null
    and tp.final_position > 0
),
event_components as (
  select
    ve.*,
    case
      when ve.final_position = 1 then p.champion_bonus
      when ve.final_position = 2 then p.runner_up_bonus
      when ve.final_position = 3 then p.third_place_bonus
      when ve.final_position <= ceil(ve.field_size * 0.50)::integer then p.top_50_bonus
      when ve.final_position <= ceil(ve.field_size * 0.70)::integer then p.top_70_bonus
      else 0::numeric
    end as finish_bonus,
    greatest(
      p.field_multiplier_floor,
      least(
        p.field_multiplier_ceiling,
        sqrt(ve.field_size::numeric / nullif(p.standard_field_size, 0))
      )
    ) as field_size_multiplier,
    case
      when ve.final_position = 1 then 'CHAMPION'
      when ve.final_position = 2 then 'RUNNER_UP'
      when ve.final_position = 3 then 'THIRD_PLACE'
      when ve.final_position <= ceil(ve.field_size * 0.50)::integer then 'TOP_50'
      when ve.final_position <= ceil(ve.field_size * 0.70)::integer then 'TOP_70'
      else 'PARTICIPATION'
    end as finish_band
  from verified_entries ve
  cross join params p
),
event_points as (
  select
    ec.*,
    round(
      p.participation_points + (ec.finish_bonus * ec.field_size_multiplier),
      4
    ) as event_points
  from event_components ec
  cross join params p
),
player_components as (
  select
    ep.player_id,
    count(*)::integer as rolling_appearances,
    sum(ep.event_points) as raw_rolling_points,
    sum(ep.finish_bonus) as raw_finish_bonus,
    max(ep.event_date) as latest_event_date,
    min(ep.final_position)::integer as best_finish,
    count(*) filter (where ep.finish_band = 'CHAMPION')::integer as championships,
    count(*) filter (where ep.finish_band in ('CHAMPION','RUNNER_UP','THIRD_PLACE'))::integer as podiums
  from event_points ep
  group by ep.player_id
),
player_factors as (
  select
    pc.*,
    case pc.rolling_appearances
      when 1 then 0.55::numeric
      when 2 then 0.70::numeric
      when 3 then 0.82::numeric
      when 4 then 0.92::numeric
      else case when pc.rolling_appearances >= 5 then 1.00::numeric else 0::numeric end
    end as confidence_factor,
    greatest(
      1.0::numeric - p.maximum_decay,
      1.0::numeric - (
        greatest(
          0,
          ceil((current_date - pc.latest_event_date - p.inactivity_grace_days) / 30.0)::integer
        ) * p.decay_per_30_days
      )
    ) as inactivity_factor
  from player_components pc
  cross join params p
),
scored_players as (
  select
    pf.*,
    round(pf.raw_rolling_points * pf.confidence_factor * pf.inactivity_factor, 2) as championship_score
  from player_factors pf
),
ranking_rows as (
  select
    player.id as player_id,
    player.display_name,
    coalesce(sp.rolling_appearances, 0) as rolling_appearances,
    case
      when coalesce(sp.rolling_appearances, 0) < 3 then 'PROVISIONAL'
      when sp.rolling_appearances < 5 then 'EMERGING'
      else 'ELIGIBLE'
    end as championship_eligibility,
    coalesce(sp.championships, 0) as championships,
    coalesce(sp.podiums, 0) as podiums,
    sp.best_finish,
    coalesce(sp.raw_rolling_points, 0)::numeric as raw_rolling_points,
    coalesce(sp.confidence_factor, 0)::numeric as confidence_factor,
    coalesce(sp.inactivity_factor, 1)::numeric as inactivity_factor,
    coalesce(sp.championship_score, 0)::numeric as championship_score,
    sp.latest_event_date,
    coalesce(stat.official_rating, stat.raw_composite, player.rating, 0)::numeric as flpr_rating
  from public.flpr_community_memberships membership
  join public.players player
    on player.id = membership.player_id
  cross join params config
  left join scored_players sp
    on sp.player_id = player.id
  left join public.player_statistics stat
    on stat.player_id = player.id
  where membership.community_id = config.community_id
    and membership.membership_status = 'active'
)
select
  row_number() over (
    order by
      rr.championship_score desc,
      rr.raw_rolling_points desc,
      rr.latest_event_date desc nulls last,
      rr.flpr_rating desc,
      rr.rolling_appearances desc,
      rr.display_name
  ) as championship_rank,
  rr.player_id,
  rr.display_name,
  rr.championship_eligibility,
  rr.rolling_appearances,
  rr.championships,
  rr.podiums,
  rr.best_finish,
  round(rr.raw_rolling_points, 2) as raw_rolling_points,
  round(rr.confidence_factor, 2) as confidence_factor,
  round(rr.inactivity_factor, 2) as inactivity_factor,
  round(rr.championship_score, 2) as championship_score,
  round(rr.flpr_rating, 2) as flpr_rating_tiebreak,
  rr.latest_event_date
from ranking_rows rr
order by championship_rank;

grant select on public.v_flpr_championship_ranking_v1 to anon, authenticated;

comment on view public.v_flpr_championship_ranking_v1 is
  'FLPR Phase 5.4B Championship Ranking v1 read-only shadow model; community-scoped rolling eight-tournament calculation.';

-- Deployment verification: expected current leaders are Ricky, Edy SP, Sandy.
select
  championship_rank,
  display_name,
  championship_eligibility,
  rolling_appearances,
  championship_score,
  championships,
  podiums
from public.v_flpr_championship_ranking_v1
order by championship_rank;

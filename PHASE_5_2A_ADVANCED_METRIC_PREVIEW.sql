-- FLPR Phase 5.2A — Advanced Metric Calculation Preview
-- READ-ONLY: creates a preview view and does not update player_statistics.

begin;

drop view if exists public.v_flpr_advanced_metric_preview;

create or replace view public.v_flpr_advanced_metric_preview
with (security_invoker = true)
as
with completed_rows as (
  select
    m.id as match_id,
    tp.player_id,
    mp.team_no,
    lower(coalesce(mp.result, '')) as result,
    abs(coalesce(m.team_a_score, 0) - coalesce(m.team_b_score, 0)) as score_margin
  from public.matches m
  join public.match_players mp on mp.match_id = m.id
  join public.tournament_players tp on tp.id = mp.tournament_player_id
  where m.status = 'completed'
    and tp.player_id is not null
), clutch as (
  select
    player_id,
    count(distinct match_id) filter (where score_margin <= 2)::integer as clutch_matches,
    count(distinct match_id) filter (where score_margin <= 2 and result in ('win','w','won'))::integer as clutch_wins,
    count(distinct match_id) filter (where score_margin <= 2 and result in ('draw','d','tie','tied'))::integer as clutch_draws
  from completed_rows
  group by player_id
), opponent_rows as (
  select distinct
    a.match_id,
    a.player_id,
    b.player_id as opponent_id
  from completed_rows a
  join completed_rows b
    on b.match_id = a.match_id
   and b.team_no <> a.team_no
   and b.player_id <> a.player_id
), schedule as (
  select
    o.player_id,
    count(*)::integer as opponent_exposures,
    avg(ops.official_rating)::numeric as average_opponent_rating
  from opponent_rows o
  join public.player_statistics ops on ops.player_id = o.opponent_id
  group by o.player_id
), partner_summary as (
  select
    player_id,
    count(*)::integer as unique_partners,
    sum(matches_played)::integer as partner_match_links,
    sum(wins)::numeric / nullif(sum(matches_played), 0) as partner_performance,
    count(*)::numeric / nullif(sum(matches_played), 0) as partner_diversity
  from public.v_flpr_relationship_live
  where relationship_type = 'partner'
  group by player_id
)
select
  p.id as player_id,
  p.display_name,
  ps.rank,
  ps.matches_played,
  c.clutch_matches,
  c.clutch_wins,
  c.clutch_draws,
  round(
    (c.clutch_wins + 0.5 * c.clutch_draws + 2.0)
    / nullif(c.clutch_matches + 4.0, 4.0),
    4
  ) as proposed_clutch,
  s.opponent_exposures,
  round(s.average_opponent_rating, 2) as average_opponent_rating,
  round(greatest(0, least(1, s.average_opponent_rating / 100.0)), 4) as proposed_schedule_strength,
  pr.unique_partners,
  pr.partner_match_links,
  round(pr.partner_performance, 4) as partner_performance,
  round(pr.partner_diversity, 4) as partner_diversity,
  round(
    greatest(0, least(1,
      0.60 * pr.partner_performance
      + 0.40 * pr.partner_diversity
    )),
    4
  ) as raw_versatility,
  round(
    greatest(0, least(1,
      (
        pr.partner_match_links::numeric
        / (pr.partner_match_links + 8.0)
      ) * (
        0.60 * pr.partner_performance
        + 0.40 * pr.partner_diversity
      )
      + (
        8.0
        / (pr.partner_match_links + 8.0)
      ) * 0.50
    )),
    4
  ) as proposed_versatility,
  ps.momentum as raw_momentum,
  round(greatest(0, least(100, 50 + 3 * ps.momentum)), 1) as proposed_momentum_index,
  ps.dominance as raw_dominance,
  round(greatest(0, least(100, 50 + 20 * ps.dominance)), 1) as proposed_dominance_index
from public.players p
join public.player_statistics ps on ps.player_id = p.id
left join clutch c on c.player_id = p.id
left join schedule s on s.player_id = p.id
left join partner_summary pr on pr.player_id = p.id
where p.status = 'active';

grant select on public.v_flpr_advanced_metric_preview to anon, authenticated;

commit;

select
  display_name,
  matches_played,
  clutch_matches,
  proposed_clutch,
  average_opponent_rating,
  proposed_schedule_strength,
  unique_partners,
  proposed_versatility,
  proposed_momentum_index,
  proposed_dominance_index
from public.v_flpr_advanced_metric_preview
order by rank, display_name;

-- FLPR Phase 5.2A — Live Partner & Opponent Relationship View
-- Completed matches only. Scheduled/unplayed matches are excluded.

begin;

create or replace view public.v_flpr_relationship_live
with (security_invoker = true)
as
with completed_player_rows as (
  select
    m.id as match_id,
    tp.player_id,
    mp.team_no,
    coalesce(mp.points_scored, 0)::numeric as points_scored,
    coalesce(mp.points_conceded, 0)::numeric as points_conceded,
    lower(coalesce(mp.result, '')) as result
  from public.matches m
  join public.match_players mp
    on mp.match_id = m.id
  join public.tournament_players tp
    on tp.id = mp.tournament_player_id
  where m.status = 'completed'
    and tp.player_id is not null
), paired_rows as (
  select
    a.player_id,
    b.player_id as related_player_id,
    case when a.team_no = b.team_no then 'partner' else 'opponent' end as relationship_type,
    a.match_id,
    a.points_scored,
    a.points_conceded,
    a.result
  from completed_player_rows a
  join completed_player_rows b
    on b.match_id = a.match_id
   and b.player_id <> a.player_id
), aggregated as (
  select
    player_id,
    related_player_id,
    relationship_type,
    count(distinct match_id)::integer as matches_played,
    count(*) filter (where result in ('win', 'w', 'won'))::integer as wins,
    count(*) filter (where result in ('draw', 'd', 'tie', 'tied'))::integer as draws,
    count(*) filter (where result in ('loss', 'l', 'lost'))::integer as losses,
    sum(points_scored)::numeric as points_for,
    sum(points_conceded)::numeric as points_against
  from paired_rows
  group by player_id, related_player_id, relationship_type
)
select
  a.player_id,
  p.display_name as player_name,
  a.related_player_id,
  rp.display_name as related_player_name,
  a.relationship_type,
  a.matches_played,
  a.wins,
  a.draws,
  a.losses,
  a.points_for,
  a.points_against,
  round(100.0 * a.wins / nullif(a.matches_played, 0), 2) as win_rate,
  round((a.points_for - a.points_against) / nullif(a.matches_played, 0), 2) as point_diff_per_match,
  case
    when a.relationship_type = 'partner' then round(
      (100.0 * a.wins / nullif(a.matches_played, 0))
      - case
          when ps.win_rate is null then 0
          when ps.win_rate <= 1 then 100.0 * ps.win_rate
          else ps.win_rate
        end,
      2
    )
    else null
  end as chemistry_delta
from aggregated a
join public.players p on p.id = a.player_id
join public.players rp on rp.id = a.related_player_id
left join public.player_statistics ps on ps.player_id = a.player_id;

grant select on public.v_flpr_relationship_live to anon, authenticated;

commit;

select
  relationship_type,
  count(*) as relationship_rows,
  count(distinct player_id) as covered_players,
  sum(matches_played) as directed_match_links
from public.v_flpr_relationship_live
group by relationship_type
order by relationship_type;

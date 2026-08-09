-- FLPR Phase 5.5A-3C1
-- Championship v2 breakdown rounding-parity hotfix
-- Recreates only the additive v2 breakdown view. No table data is changed.

begin;

create or replace view public.v_flpr_championship_event_breakdown_v2
with (security_invoker=true)
as
with params as (
  select c.id community_id,8::integer rolling_window,1::numeric participation_points,
    10::numeric champion_bonus,7::numeric runner_up_bonus,5::numeric third_place_bonus,
    3::numeric top_50_bonus,1::numeric top_70_bonus,8::numeric standard_field_size,
    .85::numeric field_floor,1.35::numeric field_ceiling
  from public.flpr_communities c where c.status='active'
), tournaments as (
  select p.community_id,t.id,t.name,
    coalesce(t.tournament_date,t.published_at::date,t.imported_at::date,t.created_at::date) event_date,
    row_number() over(partition by p.community_id order by
      coalesce(t.tournament_date,t.published_at::date,t.imported_at::date,t.created_at::date) desc,t.id desc)::integer recency_number
  from params p join public.tournaments t on t.community_id=p.community_id where t.status='published'
), entries as (
  select t.community_id,t.id tournament_id,t.name tournament_name,t.event_date,t.recency_number,
    tp.player_id,tp.final_position,count(*) over(partition by t.community_id,t.id)::integer field_size
  from tournaments t join params p using(community_id)
  join public.tournament_players tp on tp.tournament_id=t.id
  where t.recency_number<=p.rolling_window and tp.player_id is not null and tp.final_position>0
), components as (
  select e.*,
    case when final_position=1 then p.champion_bonus when final_position=2 then p.runner_up_bonus
      when final_position=3 then p.third_place_bonus
      when final_position<=ceil(field_size*.50)::integer then p.top_50_bonus
      when final_position<=ceil(field_size*.70)::integer then p.top_70_bonus else 0::numeric end finish_bonus,
    case when final_position=1 then 'CHAMPION' when final_position=2 then 'RUNNER_UP'
      when final_position=3 then 'THIRD_PLACE'
      when final_position<=ceil(field_size*.50)::integer then 'TOP_50'
      when final_position<=ceil(field_size*.70)::integer then 'TOP_70' else 'PARTICIPATION' end finish_band,
    greatest(p.field_floor,least(p.field_ceiling,sqrt(field_size::numeric/nullif(p.standard_field_size,0)))) field_multiplier,
    p.participation_points
  from entries e join params p using(community_id)
), points as (
  select components.*,
    round(participation_points+(finish_bonus*field_multiplier),4) raw_event_points
  from components
)
select r.community_id,r.community_slug,r.championship_rank,r.player_id,r.display_name,
  r.championship_eligibility,r.rolling_appearances,greatest(0,5-r.rolling_appearances)::integer appearances_to_eligible,
  r.raw_rolling_points,r.confidence_factor,r.inactivity_factor,r.championship_score,
  p.tournament_id,p.tournament_name,p.event_date,p.recency_number,p.field_size,p.final_position,
  p.finish_band,round(p.participation_points,2) participation_points,
  round(p.finish_bonus,2) finish_bonus,round(p.field_multiplier,4) field_size_multiplier,
  p.raw_event_points,
  round(p.raw_event_points*r.confidence_factor*r.inactivity_factor,4) weighted_event_contribution
from points p join public.v_flpr_championship_ranking_v2 r
  on r.community_id=p.community_id and r.player_id=p.player_id;

grant select on public.v_flpr_championship_event_breakdown_v2 to anon,authenticated;

do $$
begin
  if (select count(*) from public.v_flpr_championship_event_breakdown_v2 where community_slug='jaksel')<>45 then
    raise exception 'Championship breakdown v2 row-count parity failed';
  end if;
  if exists(
    select 1 from public.v_flpr_championship_event_breakdown_v1 old
    full join public.v_flpr_championship_event_breakdown_v2 new
      on new.community_slug='jaksel' and new.player_id=old.player_id and new.tournament_id=old.tournament_id
    where old.player_id is null or new.player_id is null
      or (to_jsonb(old)-'community_id') is distinct from (to_jsonb(new)-'community_id'-'community_slug')
  ) then
    raise exception 'Championship breakdown v2 content parity failed';
  end if;
end
$$;

commit;

with audit as (
  select 'championship_breakdown_v2_rows_are_45' audit_item,
    (select count(*)=45 from public.v_flpr_championship_event_breakdown_v2 where community_slug='jaksel') result
  union all
  select 'championship_breakdown_v2_matches_v1',not exists(
    select 1 from public.v_flpr_championship_event_breakdown_v1 old
    full join public.v_flpr_championship_event_breakdown_v2 new
      on new.community_slug='jaksel' and new.player_id=old.player_id and new.tournament_id=old.tournament_id
    where old.player_id is null or new.player_id is null
      or (to_jsonb(old)-'community_id') is distinct from (to_jsonb(new)-'community_id'-'community_slug'))
  union all
  select 'championship_ranking_v2_still_matches_v1',not exists(
    select 1 from public.v_flpr_championship_ranking_v1 old
    full join public.v_flpr_championship_ranking_v2 new
      on new.community_slug='jaksel' and new.player_id=old.player_id
    where old.player_id is null or new.player_id is null
      or to_jsonb(old) is distinct from (to_jsonb(new)-'community_id'-'community_slug'))
  union all
  select 'jakut_remains_inactive',exists(
    select 1 from public.flpr_communities where slug='jakut' and status='inactive' and not is_default)
)
select audit_item,result from audit order by audit_item;

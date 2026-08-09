-- FLPR Phase 5.5A-3C
-- Community-scoped public read-model foundation
-- Additive: v1 Jaksel views and every legacy production table are preserved.

begin;

do $$
declare
  v_jaksel uuid := (select id from public.flpr_communities where slug='jaksel');
  v_jakut uuid := (select id from public.flpr_communities where slug='jakut');
begin
  if (select count(*) from public.flpr_communities where status='active') <> 1 then
    raise exception 'Expected only Jaksel to be active before read-model installation';
  end if;
  if not exists(select 1 from public.flpr_communities where id=v_jaksel and status='active' and is_default) then
    raise exception 'Jaksel active/default guard failed';
  end if;
  if not exists(select 1 from public.flpr_communities where id=v_jakut and status='inactive' and not is_default) then
    raise exception 'Jakut inactive guard failed';
  end if;
  if (select count(*) from public.flpr_community_player_statistics where community_id=v_jaksel) <> 20
     or (select count(*) from public.flpr_community_ranking_history where community_id=v_jaksel) <> 60
     or (select count(*) from public.tournaments where community_id=v_jaksel and status='published') <> 7 then
    raise exception 'Jaksel synchronized baseline guard failed';
  end if;
  if exists(select 1 from public.flpr_community_memberships where community_id=v_jakut)
     or exists(select 1 from public.flpr_community_player_statistics where community_id=v_jakut)
     or exists(select 1 from public.tournaments where community_id=v_jakut) then
    raise exception 'Jakut must remain empty';
  end if;
end
$$;

-- Current handicap is competitive community state, not global player identity.
alter table public.flpr_community_player_statistics
  add column if not exists current_handicap numeric not null default 0,
  add column if not exists handicap_provisional boolean not null default true;

update public.flpr_community_player_statistics scoped
set current_handicap=player.handicap,
    handicap_provisional=player.provisional
from public.players player,
     public.flpr_communities community
where community.slug='jaksel'
  and scoped.community_id=community.id
  and scoped.player_id=player.id;

comment on column public.flpr_community_player_statistics.current_handicap is
  'Current handicap inside this community; never a cross-community value.';
comment on column public.flpr_community_player_statistics.handicap_provisional is
  'Community-specific handicap provisional state.';

create or replace view public.v_flpr_public_community_players
with (security_invoker=true)
as
select
  c.id as community_id,
  c.community_code,
  c.slug as community_slug,
  c.display_name as community_name,
  p.id as player_id,
  coalesce(nullif(m.local_display_name,''),p.display_name) as display_name,
  p.display_name as canonical_display_name,
  p.slug as player_slug,
  p.photo_url,
  m.membership_status,
  s.rank,s.previous_rank,s.tournaments_played,s.matches_played,
  s.wins,s.draws,s.losses,s.win_rate,s.total_points_for,s.total_points_against,
  s.point_difference,s.average_points,s.momentum,s.consistency,s.dominance,
  s.clutch_score,s.versatility,s.schedule_strength,s.championships,s.podiums,
  s.adjusted_win_rate,s.reliability,s.raw_composite,s.official_rating,
  s.rating_status,s.confidence_score,s.player_status,s.ranking_eligible,
  s.current_handicap,s.handicap_provisional,s.updated_at
from public.flpr_communities c
join public.flpr_community_memberships m on m.community_id=c.id
join public.players p on p.id=m.player_id
left join public.flpr_community_player_statistics s
  on s.community_id=m.community_id and s.player_id=m.player_id
where c.status='active'
  and m.membership_status='active'
  and p.status <> 'merged';

create or replace view public.v_flpr_public_community_tournaments
with (security_invoker=true)
as
select
  c.id as community_id,c.community_code,c.slug as community_slug,
  c.display_name as community_name,
  t.id,t.source_provider,t.source_tournament_id,t.source_url,t.name,
  t.tournament_date,t.venue,t.format,t.status,t.player_count,t.round_count,
  t.match_count,t.imported_at,t.published_at,t.cover_photo_url,t.created_at,t.updated_at
from public.flpr_communities c
join public.tournaments t on t.community_id=c.id
where c.status='active' and t.status='published';

create or replace view public.v_flpr_public_community_ranking_history
with (security_invoker=true)
as
select
  c.id as community_id,c.community_code,c.slug as community_slug,
  h.id,h.snapshot_key,h.tournament_id,h.player_id,h.rank,h.previous_rank,
  h.rank_movement,h.official_rating,h.adjusted_win_rate,h.reliability,
  h.raw_composite,h.rating_status,h.tournaments_played,h.matches_played,
  h.wins,h.draws,h.losses,h.win_rate,h.total_points_for,h.total_points_against,
  h.point_difference,h.average_points,h.momentum,h.consistency,h.dominance,
  h.clutch_score,h.versatility,h.schedule_strength,h.championships,h.podiums,
  h.snapshot_source,h.captured_at
from public.flpr_communities c
join public.flpr_community_ranking_history h on h.community_id=c.id
where c.status='active';

create or replace view public.v_flpr_public_community_rating_history
with (security_invoker=true)
as
select c.id as community_id,c.community_code,c.slug as community_slug,
  h.id,h.player_id,h.tournament_id,h.rating_before,h.rating_after,
  h.rating_change,h.calculation_version,h.created_at
from public.flpr_communities c
join public.flpr_community_rating_history h on h.community_id=c.id
where c.status='active';

create or replace view public.v_flpr_public_community_handicap_history
with (security_invoker=true)
as
select c.id as community_id,c.community_code,c.slug as community_slug,
  h.id,h.player_id,h.tournament_id,h.handicap_before,h.handicap_after,
  h.handicap_change,h.provisional,h.calculation_version,h.created_at
from public.flpr_communities c
join public.flpr_community_handicap_history h on h.community_id=c.id
where c.status='active';

-- Championship v2 calculates every active community independently.
create or replace view public.v_flpr_championship_ranking_v2
with (security_invoker=true)
as
with
params as (
  select c.id community_id,c.slug community_slug,
    8::integer rolling_window,1.0::numeric participation_points,
    10.0::numeric champion_bonus,7.0::numeric runner_up_bonus,
    5.0::numeric third_place_bonus,3.0::numeric top_50_bonus,
    1.0::numeric top_70_bonus,8.0::numeric standard_field_size,
    0.85::numeric field_floor,1.35::numeric field_ceiling,
    90::integer inactivity_grace_days,0.05::numeric decay_per_30_days,
    0.30::numeric maximum_decay
  from public.flpr_communities c where c.status='active'
),
community_tournaments as (
  select p.community_id,p.community_slug,t.id,t.name,
    coalesce(t.tournament_date,t.published_at::date,t.imported_at::date,t.created_at::date) event_date,
    row_number() over(partition by p.community_id order by
      coalesce(t.tournament_date,t.published_at::date,t.imported_at::date,t.created_at::date) desc,t.id desc)::integer recency_number
  from params p join public.tournaments t on t.community_id=p.community_id
  where t.status='published'
),
rolling_tournaments as (
  select ct.* from community_tournaments ct join params p using(community_id)
  where ct.recency_number<=p.rolling_window
),
verified_entries as (
  select rt.community_id,rt.community_slug,rt.id tournament_id,rt.name tournament_name,
    rt.event_date,rt.recency_number,tp.player_id,tp.final_position,
    count(*) over(partition by rt.community_id,rt.id)::integer field_size
  from rolling_tournaments rt join public.tournament_players tp on tp.tournament_id=rt.id
  where tp.player_id is not null and tp.final_position>0
),
event_components as (
  select ve.*,
    case when ve.final_position=1 then p.champion_bonus
      when ve.final_position=2 then p.runner_up_bonus
      when ve.final_position=3 then p.third_place_bonus
      when ve.final_position<=ceil(ve.field_size*.50)::integer then p.top_50_bonus
      when ve.final_position<=ceil(ve.field_size*.70)::integer then p.top_70_bonus
      else 0::numeric end finish_bonus,
    case when ve.final_position=1 then 'CHAMPION'
      when ve.final_position=2 then 'RUNNER_UP'
      when ve.final_position=3 then 'THIRD_PLACE'
      when ve.final_position<=ceil(ve.field_size*.50)::integer then 'TOP_50'
      when ve.final_position<=ceil(ve.field_size*.70)::integer then 'TOP_70'
      else 'PARTICIPATION' end finish_band,
    greatest(p.field_floor,least(p.field_ceiling,sqrt(ve.field_size::numeric/nullif(p.standard_field_size,0)))) field_multiplier,
    p.participation_points
  from verified_entries ve join params p using(community_id)
),
event_points as (
  select ec.*,round(ec.participation_points+(ec.finish_bonus*ec.field_multiplier),4) event_points
  from event_components ec
),
player_components as (
  select community_id,player_id,count(*)::integer rolling_appearances,
    sum(event_points) raw_rolling_points,max(event_date) latest_event_date,
    min(final_position)::integer best_finish,
    count(*) filter(where finish_band='CHAMPION')::integer championships,
    count(*) filter(where finish_band in('CHAMPION','RUNNER_UP','THIRD_PLACE'))::integer podiums
  from event_points group by community_id,player_id
),
factors as (
  select pc.*,
    case pc.rolling_appearances when 1 then .55::numeric when 2 then .70::numeric
      when 3 then .82::numeric when 4 then .92::numeric
      else case when pc.rolling_appearances>=5 then 1::numeric else 0::numeric end end confidence_factor,
    greatest(1-p.maximum_decay,1-(greatest(0,ceil((current_date-pc.latest_event_date-p.inactivity_grace_days)/30.0)::integer)*p.decay_per_30_days)) inactivity_factor
  from player_components pc join params p using(community_id)
),
scored as (
  select f.*,round(f.raw_rolling_points*f.confidence_factor*f.inactivity_factor,2) championship_score
  from factors f
),
ranking_rows as (
  select m.community_id,c.slug community_slug,p.id player_id,
    coalesce(nullif(m.local_display_name,''),p.display_name) display_name,
    coalesce(s.rolling_appearances,0) rolling_appearances,
    case when coalesce(s.rolling_appearances,0)<3 then 'PROVISIONAL'
      when s.rolling_appearances<5 then 'EMERGING' else 'ELIGIBLE' end championship_eligibility,
    coalesce(s.championships,0) championships,coalesce(s.podiums,0) podiums,
    s.best_finish,coalesce(s.raw_rolling_points,0)::numeric raw_rolling_points,
    coalesce(s.confidence_factor,0)::numeric confidence_factor,
    coalesce(s.inactivity_factor,1)::numeric inactivity_factor,
    coalesce(s.championship_score,0)::numeric championship_score,s.latest_event_date,
    coalesce(stat.official_rating,stat.raw_composite,0)::numeric flpr_rating
  from public.flpr_community_memberships m
  join public.flpr_communities c on c.id=m.community_id and c.status='active'
  join public.players p on p.id=m.player_id
  left join scored s on s.community_id=m.community_id and s.player_id=m.player_id
  left join public.flpr_community_player_statistics stat
    on stat.community_id=m.community_id and stat.player_id=m.player_id
  where m.membership_status='active' and p.status<>'merged'
)
select community_id,community_slug,
  row_number() over(partition by community_id order by championship_score desc,
    raw_rolling_points desc,latest_event_date desc nulls last,flpr_rating desc,
    rolling_appearances desc,display_name) championship_rank,
  player_id,display_name,championship_eligibility,rolling_appearances,
  championships,podiums,best_finish,round(raw_rolling_points,2) raw_rolling_points,
  round(confidence_factor,2) confidence_factor,round(inactivity_factor,2) inactivity_factor,
  round(championship_score,2) championship_score,round(flpr_rating,2) flpr_rating_tiebreak,
  latest_event_date
from ranking_rows;

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

grant select on public.v_flpr_public_community_players,
  public.v_flpr_public_community_tournaments,
  public.v_flpr_public_community_ranking_history,
  public.v_flpr_public_community_rating_history,
  public.v_flpr_public_community_handicap_history,
  public.v_flpr_championship_ranking_v2,
  public.v_flpr_championship_event_breakdown_v2
to anon,authenticated;

comment on view public.v_flpr_championship_ranking_v2 is
  'Community-partitioned Championship Ranking v2; one global player identity, independent community score.';

do $$
begin
  if (select count(*) from public.v_flpr_public_community_players where community_slug='jaksel')<>20 then
    raise exception 'Public Jaksel player view parity failed';
  end if;
  if (select count(*) from public.v_flpr_public_community_tournaments where community_slug='jaksel')<>7 then
    raise exception 'Public Jaksel tournament view parity failed';
  end if;
  if (select count(*) from public.v_flpr_public_community_ranking_history where community_slug='jaksel')<>60 then
    raise exception 'Public Jaksel history view parity failed';
  end if;
  if (select count(*) from public.v_flpr_championship_ranking_v2 where community_slug='jaksel')<>20 then
    raise exception 'Championship v2 Jaksel parity failed';
  end if;
  if (select count(*) from public.v_flpr_championship_event_breakdown_v2 where community_slug='jaksel')<>45 then
    raise exception 'Championship breakdown v2 Jaksel parity failed';
  end if;
  if exists(select 1 from public.v_flpr_public_community_players where community_slug='jakut')
     or exists(select 1 from public.v_flpr_public_community_tournaments where community_slug='jakut')
     or exists(select 1 from public.v_flpr_championship_ranking_v2 where community_slug='jakut') then
    raise exception 'Inactive Jakut leaked into public read models';
  end if;
end
$$;

commit;

with audit as (
  select 'public_jaksel_players_are_20' audit_item,
    (select count(*)=20 from public.v_flpr_public_community_players where community_slug='jaksel') result
  union all select 'public_jaksel_tournaments_are_7',
    (select count(*)=7 from public.v_flpr_public_community_tournaments where community_slug='jaksel')
  union all select 'public_jaksel_history_rows_are_60',
    (select count(*)=60 from public.v_flpr_public_community_ranking_history where community_slug='jaksel')
  union all select 'championship_v2_jaksel_rows_are_20',
    (select count(*)=20 from public.v_flpr_championship_ranking_v2 where community_slug='jaksel')
  union all select 'championship_v2_breakdown_rows_are_45',
    (select count(*)=45 from public.v_flpr_championship_event_breakdown_v2 where community_slug='jaksel')
  union all select 'championship_v2_matches_v1',not exists(
    select 1 from public.v_flpr_championship_ranking_v1 old
    full join public.v_flpr_championship_ranking_v2 new
      on new.community_slug='jaksel' and new.player_id=old.player_id
    where old.player_id is null or new.player_id is null
      or to_jsonb(old) is distinct from (to_jsonb(new)-'community_id'-'community_slug'))
  union all select 'championship_breakdown_v2_matches_v1',not exists(
    select 1 from public.v_flpr_championship_event_breakdown_v1 old
    full join public.v_flpr_championship_event_breakdown_v2 new
      on new.community_slug='jaksel' and new.player_id=old.player_id and new.tournament_id=old.tournament_id
    where old.player_id is null or new.player_id is null
      or (to_jsonb(old)-'community_id') is distinct from (to_jsonb(new)-'community_id'-'community_slug'))
  union all select 'jakut_is_not_publicly_visible',
    not exists(select 1 from public.v_flpr_public_community_players where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_public_community_tournaments where community_slug='jakut')
    and not exists(select 1 from public.v_flpr_championship_ranking_v2 where community_slug='jakut')
  union all select 'jakut_remains_inactive',exists(
    select 1 from public.flpr_communities where slug='jakut' and status='inactive' and not is_default)
  union all select 'legacy_championship_v1_preserved',
    to_regclass('public.v_flpr_championship_ranking_v1') is not null
    and to_regclass('public.v_flpr_championship_event_breakdown_v1') is not null
)
select audit_item,result from audit order by audit_item;

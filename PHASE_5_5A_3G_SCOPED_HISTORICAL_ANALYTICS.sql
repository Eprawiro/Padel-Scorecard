-- FLPR Phase 5.5A-3G
-- Community-scoped historical timeline, career statistics, and dashboard.
-- Additive/read-only views only. Existing legacy views and rows are preserved.

begin;

create or replace view public.v_flpr_community_ranking_history_timeline
with (security_invoker=true)
as
with ordered_history as (
  select
    h.community_id,c.slug community_slug,h.snapshot_key,h.snapshot_source,
    h.tournament_id,h.player_id,
    coalesce(nullif(m.local_display_name,''),p.display_name) display_name,
    h.rank,h.official_rating,h.captured_at,
    lag(h.rank) over(partition by h.community_id,h.player_id
      order by h.captured_at,h.snapshot_key) previous_historical_rank,
    lag(h.official_rating) over(partition by h.community_id,h.player_id
      order by h.captured_at,h.snapshot_key) previous_official_rating,
    row_number() over(partition by h.community_id,h.player_id
      order by h.captured_at,h.snapshot_key) player_snapshot_number,
    row_number() over(partition by h.community_id,h.player_id
      order by h.captured_at desc,h.snapshot_key desc) latest_row_number
  from public.flpr_community_ranking_history h
  join public.flpr_communities c on c.id=h.community_id and c.status='active'
  join public.flpr_community_memberships m
    on m.community_id=h.community_id and m.player_id=h.player_id
   and m.membership_status='active'
  join public.players p on p.id=h.player_id and p.status<>'merged'
)
select
  community_id,community_slug,snapshot_key,snapshot_source,tournament_id,
  player_id,display_name,rank,previous_historical_rank,
  case when previous_historical_rank is null then null::integer
       else previous_historical_rank-rank end rank_change,
  official_rating,previous_official_rating,
  case when previous_official_rating is null then null::numeric
       else round(official_rating-previous_official_rating,4) end rating_change,
  case when previous_historical_rank is null then 'BASELINE'
       when rank<previous_historical_rank then 'CLIMBING'
       when rank>previous_historical_rank then 'FALLING'
       else 'STABLE' end rank_trend,
  player_snapshot_number,latest_row_number=1 is_latest_snapshot,captured_at
from ordered_history;

create or replace view public.v_flpr_community_player_career_statistics
with (security_invoker=true)
as
with timeline as (
  select t.*,
    row_number() over(partition by t.community_id,t.player_id
      order by t.captured_at,t.snapshot_key) seq,
    count(*) over(partition by t.community_id,t.player_id) total_player_snapshots,
    max(t.rank) over(partition by t.community_id,t.snapshot_key) players_in_snapshot
  from public.v_flpr_community_ranking_history_timeline t
), first_latest as (
  select distinct on (community_id,player_id)
    community_id,community_slug,player_id,
    first_value(rank) over(partition by community_id,player_id
      order by captured_at,snapshot_key) first_recorded_rank,
    first_value(official_rating) over(partition by community_id,player_id
      order by captured_at,snapshot_key) first_recorded_rating,
    first_value(rank) over(partition by community_id,player_id
      order by captured_at desc,snapshot_key desc) current_rank,
    first_value(official_rating) over(partition by community_id,player_id
      order by captured_at desc,snapshot_key desc) current_official_rating,
    first_value(players_in_snapshot) over(partition by community_id,player_id
      order by captured_at desc,snapshot_key desc) current_field_size
  from timeline
), movement_groups as (
  select t.*,
    sum(case when rank_trend<>'CLIMBING' then 1 else 0 end)
      over(partition by community_id,player_id order by seq) improvement_group,
    sum(case when rank_trend<>'STABLE' then 1 else 0 end)
      over(partition by community_id,player_id order by seq) stability_group,
    sum(case when rank>3 then 1 else 0 end)
      over(partition by community_id,player_id order by seq) top3_group,
    sum(case when rank<>1 then 1 else 0 end)
      over(partition by community_id,player_id order by seq) number1_group
  from timeline t
), improvement_streaks as (
  select community_id,player_id,max(streak_length)::integer longest_improvement_streak
  from (select community_id,player_id,improvement_group,count(*) streak_length
    from movement_groups where rank_trend='CLIMBING'
    group by community_id,player_id,improvement_group) streak
  group by community_id,player_id
), stability_streaks as (
  select community_id,player_id,max(streak_length)::integer longest_stability_streak
  from (select community_id,player_id,stability_group,count(*) streak_length
    from movement_groups where rank_trend='STABLE'
    group by community_id,player_id,stability_group) streak
  group by community_id,player_id
), top3_streaks as (
  select community_id,player_id,max(streak_length)::integer longest_top3_streak
  from (select community_id,player_id,top3_group,count(*) streak_length
    from movement_groups where rank<=3
    group by community_id,player_id,top3_group) streak
  group by community_id,player_id
), number1_streaks as (
  select community_id,player_id,max(streak_length)::integer longest_number_one_streak
  from (select community_id,player_id,number1_group,count(*) streak_length
    from movement_groups where rank=1
    group by community_id,player_id,number1_group) streak
  group by community_id,player_id
), career_aggregates as (
  select community_id,max(community_slug) community_slug,player_id,
    max(display_name) display_name,count(*)::integer snapshot_count,
    min(rank) best_rank_ever,max(rank) worst_rank_ever,
    round(avg(rank),2) average_rank,round(stddev_pop(rank),2) rank_volatility,
    min(official_rating) lowest_official_rating,max(official_rating) highest_official_rating,
    round(avg(official_rating),4) average_official_rating,
    count(*) filter(where rank=1)::integer number_one_snapshots,
    count(*) filter(where rank<=3)::integer top_three_snapshots,
    count(*) filter(where rank<=10)::integer top_ten_snapshots,
    count(*) filter(where rank_trend='CLIMBING')::integer climbing_snapshots,
    count(*) filter(where rank_trend='FALLING')::integer falling_snapshots,
    count(*) filter(where rank_trend='STABLE')::integer stable_snapshots,
    coalesce(sum(greatest(rank_change,0)),0)::integer total_places_climbed,
    coalesce(sum(greatest(-rank_change,0)),0)::integer total_places_fallen,
    max(rank_change) biggest_single_snapshot_climb,
    min(rank_change) biggest_single_snapshot_fall,
    min(captured_at) first_snapshot_at,max(captured_at) latest_snapshot_at
  from timeline group by community_id,player_id
), latest_row as (
  select community_id,player_id,previous_historical_rank,
    rank_change latest_rank_change,rating_change latest_rating_change,
    rank_trend current_trend,snapshot_key latest_snapshot_key,
    snapshot_source latest_snapshot_source,tournament_id latest_tournament_id
  from timeline where is_latest_snapshot
), scored as (
  select a.*,f.first_recorded_rank,f.first_recorded_rating,f.current_rank,
    l.previous_historical_rank,l.latest_rank_change,l.current_trend,
    f.current_official_rating,l.latest_rating_change,
    f.first_recorded_rank-f.current_rank career_rank_improvement,
    round(f.current_official_rating-f.first_recorded_rating,4) career_rating_change,
    coalesce(i.longest_improvement_streak,0) longest_improvement_streak,
    coalesce(s.longest_stability_streak,0) longest_stability_streak,
    coalesce(t3.longest_top3_streak,0) longest_top3_streak,
    coalesce(n1.longest_number_one_streak,0) longest_number_one_streak,
    round(100.0*a.number_one_snapshots/nullif(a.snapshot_count,0),2) number_one_rate,
    round(100.0*a.top_three_snapshots/nullif(a.snapshot_count,0),2) top_three_rate,
    round(100.0*a.top_ten_snapshots/nullif(a.snapshot_count,0),2) top_ten_rate,
    l.latest_snapshot_key,l.latest_snapshot_source,l.latest_tournament_id,
    greatest(1,f.current_field_size) current_field_size
  from career_aggregates a
  join first_latest f using(community_id,player_id)
  join latest_row l using(community_id,player_id)
  left join improvement_streaks i using(community_id,player_id)
  left join stability_streaks s using(community_id,player_id)
  left join top3_streaks t3 using(community_id,player_id)
  left join number1_streaks n1 using(community_id,player_id)
)
select
  community_id,community_slug,player_id,display_name,current_rank,
  previous_historical_rank,latest_rank_change rank_change,current_trend trend_status,
  first_recorded_rank,career_rank_improvement,best_rank_ever,worst_rank_ever,
  average_rank,rank_volatility,current_official_rating,first_recorded_rating,
  career_rating_change,latest_rating_change rating_change,lowest_official_rating,
  highest_official_rating,average_official_rating,snapshot_count,
  number_one_snapshots,top_three_snapshots,top_ten_snapshots,
  number_one_rate,top_three_rate,top_ten_rate,climbing_snapshots,
  falling_snapshots,stable_snapshots,total_places_climbed,total_places_fallen,
  biggest_single_snapshot_climb,biggest_single_snapshot_fall,
  longest_improvement_streak,longest_stability_streak,longest_top3_streak,
  longest_number_one_streak,
  round(greatest(0,least(100,
    40.0*(1-(current_rank-1)::numeric/greatest(current_field_size-1,1)::numeric)
    +20.0*greatest(-1,least(1,career_rank_improvement::numeric/greatest(current_field_size-1,1)::numeric))
    +25.0*(top_three_rate/100.0)
    +15.0*greatest(-1,least(1,coalesce(career_rating_change,0)/20.0)))),2) career_trend_score,
  case when snapshot_count<3 then 'EARLY_HISTORY'
       when career_rank_improvement>=3 and coalesce(career_rating_change,0)>0 then 'STRONG_UPTREND'
       when career_rank_improvement>0 then 'UPTREND'
       when career_rank_improvement<=-3 and coalesce(career_rating_change,0)<0 then 'STRONG_DOWNTREND'
       when career_rank_improvement<0 then 'DOWNTREND'
       else 'STABLE' end career_status,
  first_snapshot_at,latest_snapshot_at,latest_snapshot_key,
  latest_snapshot_source,latest_tournament_id
from scored;

create or replace view public.v_flpr_community_player_analytics_dashboard
with (security_invoker=true)
as
select
  community_id,community_slug,player_id,display_name,current_rank,
  previous_historical_rank,rank_change,trend_status,current_official_rating,
  round(current_official_rating-coalesce(rating_change,0),4) previous_official_rating,
  rating_change,best_rank_ever,worst_rank_ever,average_rank,rank_volatility,
  number_one_snapshots,top_three_snapshots,top_three_rate,
  longest_improvement_streak,longest_stability_streak,longest_top3_streak,
  longest_number_one_streak,snapshot_count,career_rank_improvement,
  career_rating_change,career_trend_score,career_status,first_snapshot_at,
  latest_snapshot_at,latest_snapshot_key,latest_snapshot_source,latest_tournament_id,
  case when rank_change>0 then 'UP' when rank_change<0 then 'DOWN' else 'SAME' end movement_direction,
  case when snapshot_count<3 then 'EARLY_HISTORY'
       when current_rank<=3 then 'ELITE'
       when current_rank<=10 then 'TOP_TEN'
       else 'CHALLENGER' end dashboard_tier
from public.v_flpr_community_player_career_statistics;

revoke all on public.v_flpr_community_ranking_history_timeline,
  public.v_flpr_community_player_career_statistics,
  public.v_flpr_community_player_analytics_dashboard from public;
grant select on public.v_flpr_community_ranking_history_timeline,
  public.v_flpr_community_player_career_statistics,
  public.v_flpr_community_player_analytics_dashboard
  to anon,authenticated,service_role;

comment on view public.v_flpr_community_player_analytics_dashboard is
  'Community-partitioned historical analytics dashboard; no cross-community fallback.';

commit;

-- Final parity and isolation audit. Every result must be true.
with audit as (
  select 'jaksel_timeline_has_60_rows' audit_item,
    (select count(*) from public.v_flpr_community_ranking_history_timeline where community_slug='jaksel')=60 result
  union all
  select 'jaksel_timeline_matches_legacy',not exists(
    select 1 from public.v_flpr_ranking_history_timeline old
    full join public.v_flpr_community_ranking_history_timeline new
      on new.community_slug='jaksel' and new.player_id=old.player_id
     and new.snapshot_key=old.snapshot_key
    where old.player_id is null or new.player_id is null
       or to_jsonb(old) is distinct from (to_jsonb(new)-'community_id'-'community_slug'))
  union all
  select 'jaksel_career_has_20_players',
    (select count(*) from public.v_flpr_community_player_career_statistics where community_slug='jaksel')=20
  union all
  select 'jaksel_career_matches_legacy',not exists(
    select 1 from public.v_flpr_player_career_statistics old
    full join public.v_flpr_community_player_career_statistics new
      on new.community_slug='jaksel' and new.player_id=old.player_id
    where old.player_id is null or new.player_id is null
       or to_jsonb(old) is distinct from (to_jsonb(new)-'community_id'-'community_slug'))
  union all
  select 'jaksel_dashboard_has_20_players',
    (select count(*) from public.v_flpr_community_player_analytics_dashboard where community_slug='jaksel')=20
  union all
  select 'jaksel_dashboard_matches_legacy',not exists(
    select 1 from public.v_flpr_player_analytics_dashboard old
    full join public.v_flpr_community_player_analytics_dashboard new
      on new.community_slug='jaksel' and new.player_id=old.player_id
    where old.player_id is null or new.player_id is null
       or to_jsonb(old) is distinct from (to_jsonb(new)-'community_id'-'community_slug'))
  union all
  select 'inactive_jakut_has_no_timeline',not exists(
    select 1 from public.v_flpr_community_ranking_history_timeline where community_slug='jakut')
  union all
  select 'inactive_jakut_has_no_career_dashboard',
    not exists(select 1 from public.v_flpr_community_player_analytics_dashboard where community_slug='jakut')
  union all
  select 'legacy_historical_views_preserved',
    to_regclass('public.v_flpr_ranking_history_timeline') is not null
    and to_regclass('public.v_flpr_player_career_statistics') is not null
    and to_regclass('public.v_flpr_player_analytics_dashboard') is not null
)
select audit_item,result from audit order by audit_item;


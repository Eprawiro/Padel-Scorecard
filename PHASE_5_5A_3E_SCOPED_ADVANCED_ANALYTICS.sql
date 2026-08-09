-- FLPR Phase 5.5A-3E
-- Community-scoped partner/opponent and advanced performance analytics.
-- Additive and read-only: no tournament, player, ranking, or history data is changed.

begin;

create or replace view public.v_flpr_community_relationship_live
with (security_invoker=true)
as
with completed_player_rows as (
  select
    t.community_id,
    m.id as match_id,
    tp.player_id,
    mp.team_no,
    coalesce(mp.points_scored,0)::numeric as points_scored,
    coalesce(mp.points_conceded,0)::numeric as points_conceded,
    lower(coalesce(mp.result,'')) as result
  from public.flpr_communities c
  join public.tournaments t
    on t.community_id=c.id and t.status='published'
  join public.matches m
    on m.tournament_id=t.id and m.status='completed'
  join public.match_players mp on mp.match_id=m.id
  join public.tournament_players tp
    on tp.id=mp.tournament_player_id and tp.tournament_id=t.id
  join public.flpr_community_memberships membership
    on membership.community_id=t.community_id
   and membership.player_id=tp.player_id
   and membership.membership_status='active'
  where c.status='active' and tp.player_id is not null
), paired_rows as (
  select
    a.community_id,a.player_id,b.player_id as related_player_id,
    case when a.team_no=b.team_no then 'partner' else 'opponent' end as relationship_type,
    a.match_id,a.points_scored,a.points_conceded,a.result
  from completed_player_rows a
  join completed_player_rows b
    on b.community_id=a.community_id
   and b.match_id=a.match_id
   and b.player_id<>a.player_id
), aggregated as (
  select
    community_id,player_id,related_player_id,relationship_type,
    count(distinct match_id)::integer as matches_played,
    count(*) filter(where result in ('win','w','won'))::integer as wins,
    count(*) filter(where result in ('draw','d','tie','tied'))::integer as draws,
    count(*) filter(where result in ('loss','l','lost'))::integer as losses,
    sum(points_scored)::numeric as points_for,
    sum(points_conceded)::numeric as points_against
  from paired_rows
  group by community_id,player_id,related_player_id,relationship_type
)
select
  a.community_id,c.slug as community_slug,
  a.player_id,coalesce(nullif(pm.local_display_name,''),p.display_name) as player_name,
  a.related_player_id,
  coalesce(nullif(rm.local_display_name,''),rp.display_name) as related_player_name,
  a.relationship_type,a.matches_played,a.wins,a.draws,a.losses,
  a.points_for,a.points_against,
  round(100.0*a.wins/nullif(a.matches_played,0),2) as win_rate,
  round((a.points_for-a.points_against)/nullif(a.matches_played,0),2) as point_diff_per_match,
  case when a.relationship_type='partner' then round(
    (100.0*a.wins/nullif(a.matches_played,0))
    - case when ps.win_rate is null then 0
           when ps.win_rate<=1 then 100.0*ps.win_rate
           else ps.win_rate end,2)
  else null end as chemistry_delta
from aggregated a
join public.flpr_communities c on c.id=a.community_id and c.status='active'
join public.players p on p.id=a.player_id
join public.players rp on rp.id=a.related_player_id
join public.flpr_community_memberships pm
  on pm.community_id=a.community_id and pm.player_id=a.player_id
join public.flpr_community_memberships rm
  on rm.community_id=a.community_id and rm.player_id=a.related_player_id
left join public.flpr_community_player_statistics ps
  on ps.community_id=a.community_id and ps.player_id=a.player_id;

create or replace view public.v_flpr_community_advanced_metrics_live
with (security_invoker=true)
as
with completed_rows as (
  select
    t.community_id,m.id as match_id,tp.player_id,mp.team_no,
    lower(coalesce(mp.result,'')) as result,
    abs(coalesce(m.team_a_score,0)-coalesce(m.team_b_score,0)) as score_margin
  from public.flpr_communities c
  join public.tournaments t
    on t.community_id=c.id and t.status='published'
  join public.matches m
    on m.tournament_id=t.id and m.status='completed'
  join public.match_players mp on mp.match_id=m.id
  join public.tournament_players tp
    on tp.id=mp.tournament_player_id and tp.tournament_id=t.id
  join public.flpr_community_memberships membership
    on membership.community_id=t.community_id
   and membership.player_id=tp.player_id
   and membership.membership_status='active'
  where c.status='active' and tp.player_id is not null
), clutch as (
  select community_id,player_id,
    count(distinct match_id) filter(where score_margin<=2)::integer as clutch_matches,
    count(distinct match_id) filter(where score_margin<=2 and result in ('win','w','won'))::integer as clutch_wins,
    count(distinct match_id) filter(where score_margin<=2 and result in ('draw','d','tie','tied'))::integer as clutch_draws
  from completed_rows group by community_id,player_id
), opponent_rows as (
  select distinct a.community_id,a.match_id,a.player_id,b.player_id opponent_id
  from completed_rows a join completed_rows b
    on b.community_id=a.community_id and b.match_id=a.match_id
   and b.team_no<>a.team_no and b.player_id<>a.player_id
), schedule as (
  select o.community_id,o.player_id,count(*)::integer opponent_exposures,
    avg(ops.official_rating)::numeric average_opponent_rating
  from opponent_rows o
  join public.flpr_community_player_statistics ops
    on ops.community_id=o.community_id and ops.player_id=o.opponent_id
  group by o.community_id,o.player_id
), partner_summary as (
  select community_id,player_id,count(*)::integer unique_partners,
    sum(matches_played)::integer partner_match_links,
    sum(wins)::numeric/nullif(sum(matches_played),0) partner_performance,
    count(*)::numeric/nullif(sum(matches_played),0) partner_diversity
  from public.v_flpr_community_relationship_live
  where relationship_type='partner'
  group by community_id,player_id
)
select
  c.id as community_id,c.slug as community_slug,p.id as player_id,
  coalesce(nullif(m.local_display_name,''),p.display_name) as display_name,
  ps.rank,ps.matches_played,
  cl.clutch_matches,cl.clutch_wins,cl.clutch_draws,
  round((cl.clutch_wins+0.5*cl.clutch_draws+2.0)
    /nullif(cl.clutch_matches+4.0,4.0),4) as proposed_clutch,
  s.opponent_exposures,round(s.average_opponent_rating,2) average_opponent_rating,
  round(greatest(0,least(1,s.average_opponent_rating/100.0)),4) proposed_schedule_strength,
  pr.unique_partners,pr.partner_match_links,
  round(pr.partner_performance,4) partner_performance,
  round(pr.partner_diversity,4) partner_diversity,
  round(greatest(0,least(1,0.60*pr.partner_performance+0.40*pr.partner_diversity)),4) raw_versatility,
  round(greatest(0,least(1,
    (pr.partner_match_links::numeric/(pr.partner_match_links+8.0))
      *(0.60*pr.partner_performance+0.40*pr.partner_diversity)
    +(8.0/(pr.partner_match_links+8.0))*0.50)),4) proposed_versatility,
  ps.momentum raw_momentum,
  round(greatest(0,least(100,50+3*ps.momentum)),1) proposed_momentum_index,
  ps.dominance raw_dominance,
  round(greatest(0,least(100,50+20*ps.dominance)),1) proposed_dominance_index
from public.flpr_communities c
join public.flpr_community_memberships m
  on m.community_id=c.id and m.membership_status='active'
join public.players p on p.id=m.player_id and p.status<>'merged'
join public.flpr_community_player_statistics ps
  on ps.community_id=c.id and ps.player_id=p.id
left join clutch cl on cl.community_id=c.id and cl.player_id=p.id
left join schedule s on s.community_id=c.id and s.player_id=p.id
left join partner_summary pr on pr.community_id=c.id and pr.player_id=p.id
where c.status='active';

revoke all on public.v_flpr_community_relationship_live,
  public.v_flpr_community_advanced_metrics_live from public;
grant select on public.v_flpr_community_relationship_live,
  public.v_flpr_community_advanced_metrics_live to anon,authenticated,service_role;

comment on view public.v_flpr_community_relationship_live is
  'Active-community-scoped completed-match partner and opponent analytics.';
comment on view public.v_flpr_community_advanced_metrics_live is
  'Active-community-scoped advanced player metrics; no cross-community fallback.';

commit;

-- Parity and isolation audit. Every result must be true.
with audit as (
  select 'jaksel_relationship_rows_match_legacy' audit_item,
    (select count(*) from public.v_flpr_community_relationship_live where community_slug='jaksel')
      =(select count(*) from public.v_flpr_relationship_live) result
  union all
  select 'jaksel_relationship_content_matches_legacy',not exists(
    select 1
    from public.v_flpr_relationship_live old
    full join public.v_flpr_community_relationship_live new
      on new.community_slug='jaksel'
     and new.player_id=old.player_id
     and new.related_player_id=old.related_player_id
     and new.relationship_type=old.relationship_type
    where old.player_id is null or new.player_id is null
       or to_jsonb(old) is distinct from
          (to_jsonb(new)-'community_id'-'community_slug'))
  union all
  select 'jaksel_advanced_rows_match_legacy',
    (select count(*) from public.v_flpr_community_advanced_metrics_live where community_slug='jaksel')
      =(select count(*) from public.v_flpr_advanced_metrics_live)
  union all
  select 'jaksel_advanced_content_matches_legacy',not exists(
    select 1
    from public.v_flpr_advanced_metrics_live old
    full join public.v_flpr_community_advanced_metrics_live new
      on new.community_slug='jaksel' and new.player_id=old.player_id
    where old.player_id is null or new.player_id is null
       or to_jsonb(old) is distinct from
          (to_jsonb(new)-'community_id'-'community_slug'))
  union all
  select 'inactive_jakut_has_no_relationship_rows',not exists(
    select 1 from public.v_flpr_community_relationship_live where community_slug='jakut')
  union all
  select 'inactive_jakut_has_no_advanced_rows',not exists(
    select 1 from public.v_flpr_community_advanced_metrics_live where community_slug='jakut')
  union all
  select 'relationship_rows_stay_inside_membership',not exists(
    select 1 from public.v_flpr_community_relationship_live r
    where not exists(select 1 from public.flpr_community_memberships m
      where m.community_id=r.community_id and m.player_id=r.player_id and m.membership_status='active')
       or not exists(select 1 from public.flpr_community_memberships m
      where m.community_id=r.community_id and m.player_id=r.related_player_id and m.membership_status='active'))
  union all
  select 'advanced_rows_stay_inside_membership',not exists(
    select 1 from public.v_flpr_community_advanced_metrics_live a
    where not exists(select 1 from public.flpr_community_memberships m
      where m.community_id=a.community_id and m.player_id=a.player_id and m.membership_status='active'))
  union all
  select 'only_active_communities_are_exposed',not exists(
    select 1 from public.v_flpr_community_advanced_metrics_live a
    join public.flpr_communities c on c.id=a.community_id where c.status<>'active')
)
select audit_item,result from audit order by audit_item;


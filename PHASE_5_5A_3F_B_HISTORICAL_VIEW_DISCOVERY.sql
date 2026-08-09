-- FLPR Phase 5.5A-3F-B
-- READ ONLY: export this result as CSV and send it back for the scoped rebuild.

with target_views(view_name) as (
  values
    ('v_flpr_ranking_history_timeline'::text),
    ('v_flpr_player_analytics_dashboard'::text)
), definitions as (
  select
    'VIEW_DEFINITION'::text object_type,
    v.view_name object_name,
    0::integer ordinal_position,
    null::text column_name,
    null::text data_type,
    pg_get_viewdef(format('public.%I',v.view_name)::regclass,true) definition
  from target_views v
), columns as (
  select
    'VIEW_COLUMN'::text object_type,
    c.table_name object_name,
    c.ordinal_position,
    c.column_name,
    c.data_type,
    null::text definition
  from information_schema.columns c
  join target_views v on v.view_name=c.table_name
  where c.table_schema='public'
)
select * from definitions
union all
select * from columns
order by object_name,object_type desc,ordinal_position;


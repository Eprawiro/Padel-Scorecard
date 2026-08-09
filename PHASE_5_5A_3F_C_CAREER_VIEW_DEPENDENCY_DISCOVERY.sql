-- FLPR Phase 5.5A-3F-C
-- READ ONLY: recursively discovers the public view dependency chain used by
-- v_flpr_player_career_statistics, then exports definitions and columns.

with recursive view_chain as (
  select 'public.v_flpr_player_career_statistics'::regclass::oid view_oid
  union
  select referenced.oid
  from view_chain current_view
  join pg_rewrite rewrite on rewrite.ev_class=current_view.view_oid
  join pg_depend dependency on dependency.objid=rewrite.oid
  join pg_class referenced on referenced.oid=dependency.refobjid
  join pg_namespace namespace on namespace.oid=referenced.relnamespace
  where namespace.nspname='public'
    and referenced.relkind in ('v','m')
    and referenced.oid<>current_view.view_oid
), target_views as (
  select namespace.nspname schema_name,relation.relname view_name,relation.oid
  from view_chain chain
  join pg_class relation on relation.oid=chain.view_oid
  join pg_namespace namespace on namespace.oid=relation.relnamespace
), definitions as (
  select
    'VIEW_DEFINITION'::text object_type,
    view.view_name object_name,
    0::integer ordinal_position,
    null::text column_name,
    null::text data_type,
    pg_get_viewdef(view.oid,true) definition
  from target_views view
), columns as (
  select
    'VIEW_COLUMN'::text object_type,
    column_info.table_name object_name,
    column_info.ordinal_position,
    column_info.column_name,
    column_info.data_type,
    null::text definition
  from information_schema.columns column_info
  join target_views view
    on view.schema_name=column_info.table_schema
   and view.view_name=column_info.table_name
)
select * from definitions
union all
select * from columns
order by object_name,object_type desc,ordinal_position;


-- FLPR Phase 5.5A-1A — Function privilege hardening
-- Corrects Supabase default EXECUTE privileges. No data rows are changed.

begin;

revoke all on function public.flpr_create_community(text,text,text)
  from public, anon;
revoke all on function public.flpr_set_community_status(uuid,text)
  from public, anon;
revoke all on function public.flpr_assign_community_admin(uuid,uuid,text,boolean)
  from public, anon;
revoke all on function public.flpr_set_community_membership(uuid,uuid,text,text)
  from public, anon;

-- Authenticated users may reach the RPC endpoint, but every mutating function
-- still enforces Superuser or assigned Community Admin authority internally.
grant execute on function public.flpr_create_community(text,text,text)
  to authenticated, service_role;
grant execute on function public.flpr_set_community_status(uuid,text)
  to authenticated, service_role;
grant execute on function public.flpr_assign_community_admin(uuid,uuid,text,boolean)
  to authenticated, service_role;
grant execute on function public.flpr_set_community_membership(uuid,uuid,text,text)
  to authenticated, service_role;

commit;

with audit as (
  select 'anon_cannot_create_community' as audit_item,
         not has_function_privilege(
           'anon','public.flpr_create_community(text,text,text)','EXECUTE'
         ) as result
  union all
  select 'anon_cannot_set_community_status',
         not has_function_privilege(
           'anon','public.flpr_set_community_status(uuid,text)','EXECUTE'
         )
  union all
  select 'anon_cannot_assign_community_admin',
         not has_function_privilege(
           'anon','public.flpr_assign_community_admin(uuid,uuid,text,boolean)','EXECUTE'
         )
  union all
  select 'anon_cannot_manage_membership',
         not has_function_privilege(
           'anon','public.flpr_set_community_membership(uuid,uuid,text,text)','EXECUTE'
         )
  union all
  select 'authenticated_can_reach_create_rpc',
         has_function_privilege(
           'authenticated','public.flpr_create_community(text,text,text)','EXECUTE'
         )
  union all
  select 'authenticated_can_reach_assign_rpc',
         has_function_privilege(
           'authenticated','public.flpr_assign_community_admin(uuid,uuid,text,boolean)','EXECUTE'
         )
  union all
  select 'jaksel_remains_only_community',
         (select count(*) = 1 from public.flpr_communities)
  union all
  select 'jaksel_remains_active_default',
         exists(
           select 1 from public.flpr_communities
           where slug='jaksel' and status='active' and is_default
         )
)
select audit_item,result
from audit
order by audit_item;

-- FLPR Phase 5.5A-1 — Multi-Community Administration Foundation
-- Additive and baseline-safe. This script creates no second community.
-- Jaksel remains the only active/default community until explicitly changed by Superuser.

begin;

do $$
begin
  if to_regclass('public.flpr_communities') is null
     or to_regclass('public.flpr_community_memberships') is null
     or to_regclass('public.flpr_admin_community_access') is null then
    raise exception 'Phase 5.3 community foundation is not installed';
  end if;
  if not exists (
    select 1 from public.flpr_communities
    where slug = 'jaksel' and status = 'active' and is_default
  ) then
    raise exception 'Jaksel active/default baseline is missing';
  end if;
  if (select count(*) from public.flpr_community_memberships m
      join public.flpr_communities c on c.id = m.community_id
      where c.slug = 'jaksel' and m.membership_status = 'active') <> 20 then
    raise exception 'Jaksel membership guard failed: expected 20 active members';
  end if;
  if (select count(*) from public.tournaments t
      join public.flpr_communities c on c.id = t.community_id
      where c.slug = 'jaksel' and t.status = 'published') <> 7 then
    raise exception 'Jaksel tournament guard failed: expected 7 published tournaments';
  end if;
end
$$;

create or replace function public.flpr_has_community_access(
  check_community_id uuid,
  allowed_roles text[] default array['owner','admin','viewer']::text[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.flpr_is_superuser()
    or exists (
      select 1
      from public.flpr_admin_users admin_user
      join public.flpr_admin_community_access access
        on access.user_id = admin_user.user_id
      where admin_user.user_id = auth.uid()
        and admin_user.active
        and access.community_id = check_community_id
        and access.active
        and access.community_role = any(allowed_roles)
    );
$$;

revoke all on function public.flpr_has_community_access(uuid,text[]) from public;
grant execute on function public.flpr_has_community_access(uuid,text[]) to anon, authenticated, service_role;

drop policy if exists flpr_assigned_admin_reads_communities on public.flpr_communities;
create policy flpr_assigned_admin_reads_communities
  on public.flpr_communities for select to authenticated
  using (public.flpr_has_community_access(id));

drop policy if exists flpr_assigned_admin_manages_memberships on public.flpr_community_memberships;
create policy flpr_assigned_admin_manages_memberships
  on public.flpr_community_memberships for all to authenticated
  using (public.flpr_has_community_access(community_id, array['owner','admin']))
  with check (public.flpr_has_community_access(community_id, array['owner','admin']));

create or replace function public.flpr_create_community(
  p_community_code text,
  p_slug text,
  p_display_name text
)
returns public.flpr_communities
language plpgsql
security definer
set search_path = public
as $$
declare
  created_row public.flpr_communities;
  clean_code text := upper(trim(coalesce(p_community_code,'')));
  clean_slug text := lower(trim(coalesce(p_slug,'')));
  clean_name text := trim(coalesce(p_display_name,''));
begin
  if not public.flpr_is_superuser() then
    raise exception 'Superuser access required';
  end if;
  if clean_code !~ '^[A-Z0-9][A-Z0-9_-]{1,15}$' then
    raise exception 'Community code must contain 2-16 letters, numbers, underscore, or hyphen';
  end if;
  if clean_slug !~ '^[a-z0-9][a-z0-9-]{1,31}$' then
    raise exception 'Slug must contain 2-32 lowercase letters, numbers, or hyphens';
  end if;
  if length(clean_name) < 3 or length(clean_name) > 80 then
    raise exception 'Display name must contain 3-80 characters';
  end if;

  insert into public.flpr_communities(
    community_code, slug, display_name, status, is_default, settings, created_by
  ) values (
    clean_code, clean_slug, clean_name, 'inactive', false,
    jsonb_build_object(
      'ranking_scope','community',
      'rating_scope','community',
      'handicap_scope','community',
      'created_in_phase','5.5A'
    ), auth.uid()
  )
  returning * into created_row;

  insert into public.flpr_admin_community_access(
    community_id, user_id, community_role, active, created_by
  ) values (
    created_row.id, auth.uid(), 'owner', true, auth.uid()
  )
  on conflict (community_id,user_id) do update set
    community_role = 'owner', active = true, updated_at = now();

  return created_row;
end;
$$;

create or replace function public.flpr_set_community_status(
  p_community_id uuid,
  p_status text
)
returns public.flpr_communities
language plpgsql
security definer
set search_path = public
as $$
declare
  changed_row public.flpr_communities;
  clean_status text := lower(trim(coalesce(p_status,'')));
begin
  if not public.flpr_is_superuser() then
    raise exception 'Superuser access required';
  end if;
  if clean_status not in ('active','inactive','archived') then
    raise exception 'Invalid community status';
  end if;
  if exists (
    select 1 from public.flpr_communities
    where id = p_community_id and is_default and clean_status <> 'active'
  ) then
    raise exception 'The default community cannot be deactivated or archived';
  end if;

  update public.flpr_communities
  set status = clean_status, updated_at = now()
  where id = p_community_id
  returning * into changed_row;
  if changed_row.id is null then raise exception 'Community not found'; end if;
  return changed_row;
end;
$$;

create or replace function public.flpr_assign_community_admin(
  p_community_id uuid,
  p_user_id uuid,
  p_community_role text default 'admin',
  p_active boolean default true
)
returns public.flpr_admin_community_access
language plpgsql
security definer
set search_path = public
as $$
declare
  changed_row public.flpr_admin_community_access;
  clean_role text := lower(trim(coalesce(p_community_role,'')));
begin
  if not public.flpr_is_superuser() then
    raise exception 'Superuser access required';
  end if;
  if clean_role not in ('owner','admin','viewer') then
    raise exception 'Invalid community role';
  end if;
  if not exists (select 1 from public.flpr_communities where id = p_community_id) then
    raise exception 'Community not found';
  end if;
  if not exists (select 1 from public.flpr_admin_users where user_id = p_user_id and active) then
    raise exception 'Active Admin user not found';
  end if;

  insert into public.flpr_admin_community_access(
    community_id,user_id,community_role,active,created_by
  ) values (
    p_community_id,p_user_id,clean_role,coalesce(p_active,true),auth.uid()
  )
  on conflict (community_id,user_id) do update set
    community_role = excluded.community_role,
    active = excluded.active,
    updated_at = now()
  returning * into changed_row;
  return changed_row;
end;
$$;

create or replace function public.flpr_set_community_membership(
  p_community_id uuid,
  p_player_id uuid,
  p_membership_status text default 'active',
  p_local_display_name text default null
)
returns public.flpr_community_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  changed_row public.flpr_community_memberships;
  clean_status text := lower(trim(coalesce(p_membership_status,'')));
begin
  if not public.flpr_has_community_access(p_community_id,array['owner','admin']) then
    raise exception 'Community Admin access required';
  end if;
  if clean_status not in ('active','inactive','suspended','left') then
    raise exception 'Invalid membership status';
  end if;
  if not exists (select 1 from public.players where id = p_player_id and status <> 'merged') then
    raise exception 'Player not found';
  end if;

  insert into public.flpr_community_memberships(
    community_id,player_id,membership_status,local_display_name,created_by
  ) values (
    p_community_id,p_player_id,clean_status,nullif(trim(coalesce(p_local_display_name,'')),''),auth.uid()
  )
  on conflict (community_id,player_id) do update set
    membership_status = excluded.membership_status,
    local_display_name = coalesce(excluded.local_display_name,public.flpr_community_memberships.local_display_name),
    updated_at = now()
  returning * into changed_row;
  return changed_row;
end;
$$;

revoke all on function public.flpr_create_community(text,text,text) from public;
revoke all on function public.flpr_set_community_status(uuid,text) from public;
revoke all on function public.flpr_assign_community_admin(uuid,uuid,text,boolean) from public;
revoke all on function public.flpr_set_community_membership(uuid,uuid,text,text) from public;
grant execute on function public.flpr_create_community(text,text,text) to authenticated, service_role;
grant execute on function public.flpr_set_community_status(uuid,text) to authenticated, service_role;
grant execute on function public.flpr_assign_community_admin(uuid,uuid,text,boolean) to authenticated, service_role;
grant execute on function public.flpr_set_community_membership(uuid,uuid,text,text) to authenticated, service_role;

drop view if exists public.v_flpr_public_communities;
create view public.v_flpr_public_communities
with (security_invoker = true)
as
select
  c.id,
  c.community_code,
  c.slug,
  c.display_name,
  c.is_default,
  c.status,
  count(distinct m.player_id) filter (where m.membership_status = 'active')::integer as active_players,
  count(distinct t.id) filter (where t.status = 'published')::integer as published_tournaments
from public.flpr_communities c
left join public.flpr_community_memberships m on m.community_id = c.id
left join public.tournaments t on t.community_id = c.id
where c.status = 'active'
group by c.id,c.community_code,c.slug,c.display_name,c.is_default,c.status;

grant select on public.v_flpr_public_communities to anon,authenticated;

do $$
begin
  if (select count(*) from public.flpr_communities where status = 'active') <> 1 then
    raise exception 'Safety guard failed: Phase 5.5A-1 expects only Jaksel active';
  end if;
  if (select count(*) from public.v_flpr_public_communities where slug = 'jaksel'
      and active_players = 20 and published_tournaments = 7) <> 1 then
    raise exception 'Jaksel public parity failed after installation';
  end if;
end
$$;

commit;

with audit as (
  select 'active_community_count_is_one' audit_item,
         (select count(*) = 1 from public.flpr_communities where status='active') result
  union all
  select 'jaksel_is_default_and_active',
         exists(select 1 from public.flpr_communities where slug='jaksel' and status='active' and is_default)
  union all
  select 'jaksel_has_20_active_members',
         (select active_players=20 from public.v_flpr_public_communities where slug='jaksel')
  union all
  select 'jaksel_has_7_published_tournaments',
         (select published_tournaments=7 from public.v_flpr_public_communities where slug='jaksel')
  union all
  select 'create_community_is_superuser_only',
         not has_function_privilege('anon','public.flpr_create_community(text,text,text)','EXECUTE')
  union all
  select 'assign_admin_is_superuser_only',
         not has_function_privilege('anon','public.flpr_assign_community_admin(uuid,uuid,text,boolean)','EXECUTE')
  union all
  select 'membership_function_exists',
         to_regprocedure('public.flpr_set_community_membership(uuid,uuid,text,text)') is not null
  union all
  select 'no_second_community_created',
         (select count(*)=1 from public.flpr_communities)
)
select audit_item,result from audit order by audit_item;

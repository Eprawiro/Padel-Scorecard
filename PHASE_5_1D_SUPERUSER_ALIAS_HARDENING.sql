-- FLPR Phase 5.1D — Superuser-only Player Alias mutations
begin;

create or replace function public.flpr_is_superuser(check_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.flpr_admin_users a
    where a.user_id = check_user
      and a.active
      and a.role = 'superuser'
  );
$function$;

revoke all on function public.flpr_is_superuser(uuid) from public;
grant execute on function public.flpr_is_superuser(uuid) to authenticated;
grant select, insert, update, delete on table public.flpr_player_aliases to authenticated;

drop policy if exists "admin aliases read" on public.flpr_player_aliases;
drop policy if exists "admin aliases insert" on public.flpr_player_aliases;
drop policy if exists "admin aliases update" on public.flpr_player_aliases;
drop policy if exists "admin aliases delete" on public.flpr_player_aliases;
drop policy if exists "active admins read aliases" on public.flpr_player_aliases;
drop policy if exists "superuser inserts aliases" on public.flpr_player_aliases;
drop policy if exists "superuser updates aliases" on public.flpr_player_aliases;
drop policy if exists "superuser deletes aliases" on public.flpr_player_aliases;

create policy "active admins read aliases" on public.flpr_player_aliases
for select to authenticated using (public.flpr_is_active_admin());
create policy "superuser inserts aliases" on public.flpr_player_aliases
for insert to authenticated with check (public.flpr_is_superuser());
create policy "superuser updates aliases" on public.flpr_player_aliases
for update to authenticated using (public.flpr_is_superuser()) with check (public.flpr_is_superuser());
create policy "superuser deletes aliases" on public.flpr_player_aliases
for delete to authenticated using (public.flpr_is_superuser());

commit;

select policyname, cmd, roles from pg_policies
where schemaname = 'public' and tablename = 'flpr_player_aliases'
order by cmd, policyname;

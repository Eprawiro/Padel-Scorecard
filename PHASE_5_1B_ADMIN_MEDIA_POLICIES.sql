-- FLPR Phase 5.1B — Admin media metadata policies
-- Run once in Supabase SQL Editor before deploying the Phase 5.1B frontend.

begin;

drop policy if exists flpr_players_admin_update on public.players;
create policy flpr_players_admin_update on public.players
for update to authenticated
using (public.flpr_is_active_admin())
with check (public.flpr_is_active_admin());

drop policy if exists flpr_tournaments_admin_update on public.tournaments;
create policy flpr_tournaments_admin_update on public.tournaments
for update to authenticated
using (public.flpr_is_active_admin())
with check (public.flpr_is_active_admin());

commit;

select
  policyname,
  tablename,
  cmd,
  roles
from pg_policies
where schemaname = 'public'
  and policyname in ('flpr_players_admin_update','flpr_tournaments_admin_update')
order by tablename;

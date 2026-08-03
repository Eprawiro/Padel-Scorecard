-- FLPR Phase 5.3B — Explicit REST grants for community foundation
-- Permissions only. No production rows are changed.

begin;

grant select on public.flpr_communities
  to anon, authenticated;
grant select on public.flpr_community_memberships
  to anon, authenticated;
grant select on public.flpr_community_player_statistics
  to anon, authenticated;
grant select on public.flpr_community_ranking_history
  to anon, authenticated;
grant select on public.flpr_community_rating_history
  to anon, authenticated;
grant select on public.flpr_community_handicap_history
  to anon, authenticated;

grant insert, update, delete on public.flpr_communities
  to authenticated;
grant insert, update, delete on public.flpr_community_memberships
  to authenticated;
grant insert, update, delete on public.flpr_community_player_statistics
  to authenticated;
grant insert, update, delete on public.flpr_community_ranking_history
  to authenticated;
grant insert, update, delete on public.flpr_community_rating_history
  to authenticated;
grant insert, update, delete on public.flpr_community_handicap_history
  to authenticated;

grant select, insert, update, delete on public.flpr_admin_community_access
  to authenticated;

commit;

select
  has_table_privilege('anon', 'public.flpr_communities', 'select') as anon_communities,
  has_table_privilege('anon', 'public.flpr_community_memberships', 'select') as anon_memberships,
  has_table_privilege('anon', 'public.flpr_community_player_statistics', 'select') as anon_statistics,
  has_table_privilege('authenticated', 'public.flpr_communities', 'select') as authenticated_communities,
  has_table_privilege('authenticated', 'public.flpr_admin_community_access', 'select') as authenticated_admin_access;

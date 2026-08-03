-- FLPR Phase 5.3B — Additive Multi-Community Foundation
-- Production migration with strict Jaksel baseline guards.
-- Existing IDs and legacy tables are preserved for backward compatibility.

begin;

do $$
begin
  if (select count(*) from public.players where status <> 'merged') <> 20 then
    raise exception 'Baseline guard failed: expected 20 non-merged players';
  end if;
  if (select count(*) from public.tournaments where status = 'published') <> 6 then
    raise exception 'Baseline guard failed: expected 6 published tournaments';
  end if;
  if (select count(*) from public.player_statistics) <> 20 then
    raise exception 'Baseline guard failed: expected 20 player_statistics rows';
  end if;
  if (select count(*) from public.ranking_history) <> 40 then
    raise exception 'Baseline guard failed: expected 40 ranking_history rows';
  end if;
  if (select count(*) from public.matches where status = 'completed') <> 63 then
    raise exception 'Baseline guard failed: expected 63 completed matches';
  end if;
end
$$;

create table if not exists public.flpr_communities (
  id uuid primary key default gen_random_uuid(),
  community_code text not null unique,
  slug text not null unique,
  display_name text not null,
  status text not null default 'active' check (status in ('active','inactive','archived')),
  is_default boolean not null default false,
  settings jsonb not null default '{}'::jsonb,
  created_by uuid default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists flpr_communities_one_default_uq
  on public.flpr_communities (is_default)
  where is_default;

insert into public.flpr_communities (
  id, community_code, slug, display_name, status, is_default, settings
)
values (
  '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid,
  'JAKSEL',
  'jaksel',
  'Jakarta Selatan',
  'active',
  true,
  jsonb_build_object(
    'flagship', true,
    'legacy_baseline', 'T1-T6',
    'ranking_scope', 'community',
    'rating_scope', 'community',
    'handicap_scope', 'community'
  )
)
on conflict (id) do update set
  community_code = excluded.community_code,
  slug = excluded.slug,
  display_name = excluded.display_name,
  status = excluded.status,
  is_default = excluded.is_default,
  settings = excluded.settings,
  updated_at = now();

create table if not exists public.flpr_community_memberships (
  community_id uuid not null references public.flpr_communities(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  membership_status text not null default 'active'
    check (membership_status in ('active','inactive','suspended','left')),
  local_display_name text,
  joined_at timestamptz not null default now(),
  created_by uuid default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (community_id, player_id)
);

insert into public.flpr_community_memberships (
  community_id, player_id, membership_status, local_display_name, joined_at
)
select
  '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid,
  p.id,
  case when p.status = 'active' then 'active' else 'inactive' end,
  p.display_name,
  p.created_at
from public.players p
where p.status <> 'merged'
on conflict (community_id, player_id) do nothing;

create table if not exists public.flpr_community_player_statistics (
  community_id uuid not null references public.flpr_communities(id) on delete cascade,
  like public.player_statistics including defaults including constraints,
  primary key (community_id, player_id),
  foreign key (player_id) references public.players(id) on delete cascade,
  foreign key (community_id, player_id)
    references public.flpr_community_memberships(community_id, player_id)
    on delete cascade
);

insert into public.flpr_community_player_statistics
select
  '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid,
  ps.*
from public.player_statistics ps
on conflict (community_id, player_id) do nothing;

create table if not exists public.flpr_community_ranking_history (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.flpr_communities(id) on delete cascade,
  legacy_ranking_history_id bigint,
  snapshot_key text not null,
  tournament_id uuid references public.tournaments(id) on delete set null,
  player_id uuid not null references public.players(id) on delete cascade,
  rank integer not null check (rank > 0),
  previous_rank integer check (previous_rank is null or previous_rank > 0),
  rank_movement integer,
  official_rating numeric,
  adjusted_win_rate numeric,
  reliability numeric,
  raw_composite numeric,
  rating_status text,
  tournaments_played integer not null default 0,
  matches_played integer not null default 0,
  wins integer not null default 0,
  draws integer not null default 0,
  losses integer not null default 0,
  win_rate numeric,
  total_points_for numeric not null default 0,
  total_points_against numeric not null default 0,
  point_difference numeric not null default 0,
  average_points numeric,
  momentum numeric,
  consistency numeric,
  dominance numeric,
  clutch_score numeric,
  versatility numeric,
  schedule_strength numeric,
  championships integer not null default 0,
  podiums integer not null default 0,
  snapshot_source text not null default 'system',
  captured_at timestamptz not null default now(),
  unique (community_id, snapshot_key, player_id),
  foreign key (community_id, player_id)
    references public.flpr_community_memberships(community_id, player_id)
    on delete cascade
);

insert into public.flpr_community_ranking_history (
  community_id, legacy_ranking_history_id, snapshot_key, tournament_id, player_id,
  rank, previous_rank, rank_movement, official_rating, adjusted_win_rate,
  reliability, raw_composite, rating_status, tournaments_played, matches_played,
  wins, draws, losses, win_rate, total_points_for, total_points_against,
  point_difference, average_points, momentum, consistency, dominance,
  clutch_score, versatility, schedule_strength, championships, podiums,
  snapshot_source, captured_at
)
select
  '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid,
  rh.id, rh.snapshot_key, rh.tournament_id, rh.player_id,
  rh.rank, rh.previous_rank, rh.rank_movement, rh.official_rating,
  rh.adjusted_win_rate, rh.reliability, rh.raw_composite, rh.rating_status,
  rh.tournaments_played, rh.matches_played, rh.wins, rh.draws, rh.losses,
  rh.win_rate, rh.total_points_for, rh.total_points_against,
  rh.point_difference, rh.average_points, rh.momentum, rh.consistency,
  rh.dominance, rh.clutch_score, rh.versatility, rh.schedule_strength,
  rh.championships, rh.podiums, rh.snapshot_source, rh.captured_at
from public.ranking_history rh
on conflict (community_id, snapshot_key, player_id) do nothing;

create table if not exists public.flpr_community_rating_history (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.flpr_communities(id) on delete cascade,
  legacy_rating_history_id uuid,
  player_id uuid not null references public.players(id) on delete cascade,
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  rating_before numeric not null,
  rating_after numeric not null,
  rating_change numeric,
  calculation_version text not null default 'flpr-v1',
  created_at timestamptz not null default now(),
  unique (community_id, player_id, tournament_id),
  foreign key (community_id, player_id)
    references public.flpr_community_memberships(community_id, player_id)
    on delete cascade
);

insert into public.flpr_community_rating_history (
  community_id, legacy_rating_history_id, player_id, tournament_id,
  rating_before, rating_after, rating_change, calculation_version, created_at
)
select
  '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid,
  h.id, h.player_id, h.tournament_id, h.rating_before, h.rating_after,
  h.rating_change, h.calculation_version, h.created_at
from public.rating_history h
on conflict (community_id, player_id, tournament_id) do nothing;

create table if not exists public.flpr_community_handicap_history (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.flpr_communities(id) on delete cascade,
  legacy_handicap_history_id uuid,
  player_id uuid not null references public.players(id) on delete cascade,
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  handicap_before numeric not null,
  handicap_after numeric not null,
  handicap_change numeric,
  provisional boolean not null default true,
  calculation_version text not null default 'flpr-v1',
  created_at timestamptz not null default now(),
  unique (community_id, player_id, tournament_id),
  foreign key (community_id, player_id)
    references public.flpr_community_memberships(community_id, player_id)
    on delete cascade
);

insert into public.flpr_community_handicap_history (
  community_id, legacy_handicap_history_id, player_id, tournament_id,
  handicap_before, handicap_after, handicap_change, provisional,
  calculation_version, created_at
)
select
  '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid,
  h.id, h.player_id, h.tournament_id, h.handicap_before, h.handicap_after,
  h.handicap_change, h.provisional, h.calculation_version, h.created_at
from public.handicap_history h
on conflict (community_id, player_id, tournament_id) do nothing;

create table if not exists public.flpr_admin_community_access (
  community_id uuid not null references public.flpr_communities(id) on delete cascade,
  user_id uuid not null references public.flpr_admin_users(user_id) on delete cascade,
  community_role text not null default 'admin'
    check (community_role in ('owner','admin','viewer')),
  active boolean not null default true,
  created_by uuid default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (community_id, user_id)
);

insert into public.flpr_admin_community_access (
  community_id, user_id, community_role, active
)
select
  '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid,
  a.user_id,
  case when a.role = 'superuser' then 'owner' else 'admin' end,
  a.active
from public.flpr_admin_users a
on conflict (community_id, user_id) do update set
  community_role = excluded.community_role,
  active = excluded.active,
  updated_at = now();

alter table public.tournaments
  add column if not exists community_id uuid;

update public.tournaments
set community_id = '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid
where community_id is null;

alter table public.tournaments
  alter column community_id set default '8f4c2b6e-7d91-4a53-9c20-000000000001'::uuid,
  alter column community_id set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'tournaments_community_id_fkey'
      and conrelid = 'public.tournaments'::regclass
  ) then
    alter table public.tournaments
      add constraint tournaments_community_id_fkey
      foreign key (community_id)
      references public.flpr_communities(id);
  end if;
end
$$;

create index if not exists tournaments_community_date_idx
  on public.tournaments (community_id, tournament_date desc);

alter table public.flpr_communities enable row level security;
alter table public.flpr_community_memberships enable row level security;
alter table public.flpr_community_player_statistics enable row level security;
alter table public.flpr_community_ranking_history enable row level security;
alter table public.flpr_community_rating_history enable row level security;
alter table public.flpr_community_handicap_history enable row level security;
alter table public.flpr_admin_community_access enable row level security;

grant select on public.flpr_communities, public.flpr_community_memberships,
  public.flpr_community_player_statistics, public.flpr_community_ranking_history,
  public.flpr_community_rating_history, public.flpr_community_handicap_history
  to anon, authenticated;
grant insert, update, delete on public.flpr_communities,
  public.flpr_community_memberships, public.flpr_community_player_statistics,
  public.flpr_community_ranking_history, public.flpr_community_rating_history,
  public.flpr_community_handicap_history
  to authenticated;
grant select, insert, update, delete on public.flpr_admin_community_access
  to authenticated;

drop policy if exists flpr_public_reads_active_communities on public.flpr_communities;
create policy flpr_public_reads_active_communities
  on public.flpr_communities for select to anon, authenticated
  using (status = 'active');

drop policy if exists flpr_public_reads_memberships on public.flpr_community_memberships;
create policy flpr_public_reads_memberships
  on public.flpr_community_memberships for select to anon, authenticated
  using (true);

drop policy if exists flpr_public_reads_community_statistics on public.flpr_community_player_statistics;
create policy flpr_public_reads_community_statistics
  on public.flpr_community_player_statistics for select to anon, authenticated
  using (true);

drop policy if exists flpr_public_reads_community_ranking_history on public.flpr_community_ranking_history;
create policy flpr_public_reads_community_ranking_history
  on public.flpr_community_ranking_history for select to anon, authenticated
  using (true);

drop policy if exists flpr_public_reads_community_rating_history on public.flpr_community_rating_history;
create policy flpr_public_reads_community_rating_history
  on public.flpr_community_rating_history for select to anon, authenticated
  using (true);

drop policy if exists flpr_public_reads_community_handicap_history on public.flpr_community_handicap_history;
create policy flpr_public_reads_community_handicap_history
  on public.flpr_community_handicap_history for select to anon, authenticated
  using (true);

drop policy if exists flpr_superuser_manages_communities on public.flpr_communities;
create policy flpr_superuser_manages_communities
  on public.flpr_communities for all to authenticated
  using (public.flpr_is_superuser())
  with check (public.flpr_is_superuser());

drop policy if exists flpr_superuser_manages_memberships on public.flpr_community_memberships;
create policy flpr_superuser_manages_memberships
  on public.flpr_community_memberships for all to authenticated
  using (public.flpr_is_superuser())
  with check (public.flpr_is_superuser());

drop policy if exists flpr_superuser_manages_community_statistics on public.flpr_community_player_statistics;
create policy flpr_superuser_manages_community_statistics
  on public.flpr_community_player_statistics for all to authenticated
  using (public.flpr_is_superuser())
  with check (public.flpr_is_superuser());

drop policy if exists flpr_superuser_manages_community_histories on public.flpr_community_ranking_history;
create policy flpr_superuser_manages_community_histories
  on public.flpr_community_ranking_history for all to authenticated
  using (public.flpr_is_superuser())
  with check (public.flpr_is_superuser());

drop policy if exists flpr_superuser_manages_community_rating_history on public.flpr_community_rating_history;
create policy flpr_superuser_manages_community_rating_history
  on public.flpr_community_rating_history for all to authenticated
  using (public.flpr_is_superuser())
  with check (public.flpr_is_superuser());

drop policy if exists flpr_superuser_manages_community_handicap_history on public.flpr_community_handicap_history;
create policy flpr_superuser_manages_community_handicap_history
  on public.flpr_community_handicap_history for all to authenticated
  using (public.flpr_is_superuser())
  with check (public.flpr_is_superuser());

drop policy if exists flpr_admin_reads_own_community_access on public.flpr_admin_community_access;
create policy flpr_admin_reads_own_community_access
  on public.flpr_admin_community_access for select to authenticated
  using (user_id = auth.uid() or public.flpr_is_superuser());

drop policy if exists flpr_superuser_manages_community_access on public.flpr_admin_community_access;
create policy flpr_superuser_manages_community_access
  on public.flpr_admin_community_access for all to authenticated
  using (public.flpr_is_superuser())
  with check (public.flpr_is_superuser());

do $$
begin
  if (select count(*) from public.flpr_communities where slug = 'jaksel') <> 1 then
    raise exception 'Post-migration parity failed: Jaksel community';
  end if;
  if (select count(*) from public.flpr_community_memberships where community_id = '8f4c2b6e-7d91-4a53-9c20-000000000001') <> 20 then
    raise exception 'Post-migration parity failed: 20 Jaksel memberships';
  end if;
  if (select count(*) from public.flpr_community_player_statistics where community_id = '8f4c2b6e-7d91-4a53-9c20-000000000001') <> 20 then
    raise exception 'Post-migration parity failed: 20 Jaksel statistics rows';
  end if;
  if (select count(*) from public.tournaments where community_id = '8f4c2b6e-7d91-4a53-9c20-000000000001' and status = 'published') <> 6 then
    raise exception 'Post-migration parity failed: 6 Jaksel tournaments';
  end if;
  if (select count(*) from public.flpr_community_ranking_history where community_id = '8f4c2b6e-7d91-4a53-9c20-000000000001') <> 40 then
    raise exception 'Post-migration parity failed: 40 Jaksel ranking rows';
  end if;
end
$$;

commit;

select 'communities' as audit_item, count(*)::text as result from public.flpr_communities
union all
select 'jaksel_memberships', count(*)::text from public.flpr_community_memberships where community_id = '8f4c2b6e-7d91-4a53-9c20-000000000001'
union all
select 'jaksel_statistics', count(*)::text from public.flpr_community_player_statistics where community_id = '8f4c2b6e-7d91-4a53-9c20-000000000001'
union all
select 'jaksel_published_tournaments', count(*)::text from public.tournaments where community_id = '8f4c2b6e-7d91-4a53-9c20-000000000001' and status = 'published'
union all
select 'jaksel_ranking_history', count(*)::text from public.flpr_community_ranking_history where community_id = '8f4c2b6e-7d91-4a53-9c20-000000000001'
union all
select 'jaksel_admin_access', count(*)::text from public.flpr_admin_community_access where community_id = '8f4c2b6e-7d91-4a53-9c20-000000000001'
union all
select 'legacy_players', count(*)::text from public.players
union all
select 'legacy_player_statistics', count(*)::text from public.player_statistics
union all
select 'legacy_published_tournaments', count(*)::text from public.tournaments where status = 'published'
union all
select 'legacy_completed_matches', count(*)::text from public.matches where status = 'completed'
order by audit_item;

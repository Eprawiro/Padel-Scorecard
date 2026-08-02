-- FLPR Phase 5.1C — Player Alias Manager
create extension if not exists pgcrypto;

create table if not exists public.flpr_player_aliases (
  id uuid primary key default gen_random_uuid(),
  alias_name text not null,
  alias_key text generated always as (lower(regexp_replace(trim(alias_name), '[^a-zA-Z0-9]+', ' ', 'g'))) stored,
  canonical_player_id uuid not null references public.players(id) on delete cascade,
  is_active boolean not null default true,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint flpr_player_aliases_alias_name_check check (char_length(trim(alias_name)) between 2 and 80),
  constraint flpr_player_aliases_alias_key_unique unique(alias_key)
);

alter table public.flpr_player_aliases enable row level security;

drop policy if exists "admin aliases read" on public.flpr_player_aliases;
create policy "admin aliases read" on public.flpr_player_aliases for select to authenticated using (true);
drop policy if exists "admin aliases insert" on public.flpr_player_aliases;
create policy "admin aliases insert" on public.flpr_player_aliases for insert to authenticated with check (true);
drop policy if exists "admin aliases update" on public.flpr_player_aliases;
create policy "admin aliases update" on public.flpr_player_aliases for update to authenticated using (true) with check (true);
drop policy if exists "admin aliases delete" on public.flpr_player_aliases;
create policy "admin aliases delete" on public.flpr_player_aliases for delete to authenticated using (true);

insert into public.flpr_player_aliases(alias_name,canonical_player_id)
select 'Edy', id from public.players where lower(trim(display_name))='edy sp'
on conflict (alias_key) do update set canonical_player_id=excluded.canonical_player_id,is_active=true,updated_at=now();
insert into public.flpr_player_aliases(alias_name,canonical_player_id)
select 'Sandi', id from public.players where lower(trim(display_name))='sandy'
on conflict (alias_key) do update set canonical_player_id=excluded.canonical_player_id,is_active=true,updated_at=now();
insert into public.flpr_player_aliases(alias_name,canonical_player_id)
select 'Niko', id from public.players where lower(trim(display_name))='nico'
on conflict (alias_key) do update set canonical_player_id=excluded.canonical_player_id,is_active=true,updated_at=now();

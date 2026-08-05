-- FLPR Phase 5.4D — Dedicated Championship Ranking History table
-- FOUNDATION ONLY: creates an empty, protected table.
-- No backfill, capture function, trigger, or automatic write is enabled.

begin;

create table if not exists public.flpr_championship_ranking_history (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null
    references public.flpr_communities(id) on delete restrict,
  tournament_id uuid not null
    references public.tournaments(id) on delete restrict,
  player_id uuid not null
    references public.players(id) on delete restrict,
  calculation_version text not null default 'championship-v1',
  snapshot_key text not null,
  championship_rank integer not null check (championship_rank > 0),
  previous_rank integer check (previous_rank is null or previous_rank > 0),
  rank_movement integer,
  championship_score numeric not null check (championship_score >= 0),
  previous_score numeric check (previous_score is null or previous_score >= 0),
  score_change numeric,
  championship_eligibility text not null
    check (championship_eligibility in ('ELIGIBLE', 'EMERGING', 'PROVISIONAL')),
  rolling_appearances integer not null default 0 check (rolling_appearances >= 0),
  raw_rolling_points numeric not null default 0 check (raw_rolling_points >= 0),
  confidence_factor numeric not null check (confidence_factor between 0 and 1),
  inactivity_factor numeric not null check (inactivity_factor between 0.70 and 1),
  championships integer not null default 0 check (championships >= 0),
  podiums integer not null default 0 check (podiums >= 0),
  best_finish integer check (best_finish is null or best_finish > 0),
  latest_event_date date,
  snapshot_source text not null default 'tournament_publish',
  captured_at timestamptz not null default now(),
  unique (community_id, tournament_id, player_id, calculation_version),
  unique (community_id, snapshot_key, player_id, calculation_version),
  foreign key (community_id, player_id)
    references public.flpr_community_memberships(community_id, player_id)
    on delete restrict
);

create index if not exists flpr_championship_history_player_timeline_idx
  on public.flpr_championship_ranking_history
  (community_id, player_id, captured_at desc);

create index if not exists flpr_championship_history_tournament_rank_idx
  on public.flpr_championship_ranking_history
  (community_id, tournament_id, championship_rank);

alter table public.flpr_championship_ranking_history enable row level security;

drop policy if exists flpr_public_reads_championship_history
  on public.flpr_championship_ranking_history;

create policy flpr_public_reads_championship_history
  on public.flpr_championship_ranking_history
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.flpr_communities community
      where community.id = flpr_championship_ranking_history.community_id
        and community.status = 'active'
    )
  );

revoke insert, update, delete, truncate
  on public.flpr_championship_ranking_history
  from anon, authenticated;

grant select
  on public.flpr_championship_ranking_history
  to anon, authenticated;

comment on table public.flpr_championship_ranking_history is
  'Dedicated, community-scoped Championship Ranking snapshot history. Phase 5.4D foundation; no automatic capture enabled.';

commit;

-- Post-migration verification. Expected: every result is true.
with audit as (
  select 'table_exists'::text as audit_item,
    (to_regclass('public.flpr_championship_ranking_history') is not null) as result
  union all
  select 'table_starts_empty',
    ((select count(*) from public.flpr_championship_ranking_history) = 0)
  union all
  select 'row_level_security_enabled',
    (select c.relrowsecurity from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = 'flpr_championship_ranking_history')
  union all
  select 'public_select_policy_exists',
    exists (select 1 from pg_policies
      where schemaname = 'public'
        and tablename = 'flpr_championship_ranking_history'
        and policyname = 'flpr_public_reads_championship_history'
        and cmd = 'SELECT')
  union all
  select 'anon_has_select_only',
    exists (select 1 from information_schema.role_table_grants
      where table_schema = 'public' and table_name = 'flpr_championship_ranking_history'
        and grantee = 'anon' and privilege_type = 'SELECT')
    and not exists (select 1 from information_schema.role_table_grants
      where table_schema = 'public' and table_name = 'flpr_championship_ranking_history'
        and grantee = 'anon' and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE'))
  union all
  select 'authenticated_has_select_only',
    exists (select 1 from information_schema.role_table_grants
      where table_schema = 'public' and table_name = 'flpr_championship_ranking_history'
        and grantee = 'authenticated' and privilege_type = 'SELECT')
    and not exists (select 1 from information_schema.role_table_grants
      where table_schema = 'public' and table_name = 'flpr_championship_ranking_history'
        and grantee = 'authenticated' and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE'))
  union all
  select 'tournament_player_version_unique',
    exists (
      select 1 from pg_constraint
      where conrelid = 'public.flpr_championship_ranking_history'::regclass
        and contype = 'u'
        and pg_get_constraintdef(oid) ilike '%community_id, tournament_id, player_id, calculation_version%'
    )
  union all
  select 'existing_flpr_history_preserved',
    ((select count(*) from public.flpr_community_ranking_history) = 40)
  union all
  select 'current_championship_view_preserved',
    ((select count(*) from public.v_flpr_championship_ranking_v1) = 20)
  union all
  select 'event_breakdown_view_preserved',
    ((select count(*) from public.v_flpr_championship_event_breakdown_v1) = 45)
  union all
  select 'no_capture_trigger_enabled',
    not exists (
      select 1 from pg_trigger tr
      join pg_class cl on cl.oid = tr.tgrelid
      join pg_namespace ns on ns.oid = cl.relnamespace
      where ns.nspname = 'public'
        and not tr.tgisinternal
        and (tr.tgname ilike '%championship%' or pg_get_triggerdef(tr.oid) ilike '%championship%')
    )
)
select audit_item, result
from audit
order by audit_item;

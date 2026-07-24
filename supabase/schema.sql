-- Gym Bro schema
-- Run this once in the Supabase SQL Editor (Dashboard > SQL Editor > New query) after creating your project.
-- Every table carries its own user_id (denormalized) so Row Level Security policies stay a simple
-- `auth.uid() = user_id` check on each table, rather than nested joins up to `routines`.
--
-- If you already ran an earlier version of this file, don't re-run it — use the
-- files in supabase/migrations/ instead, which upgrade an existing database in
-- place. This file is the canonical from-scratch shape.

create table if not exists routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  -- Optional subtitle shown after the "Routine A"/"Routine B" title. The
  -- letter itself is computed from position (sort_order) in the app, not
  -- stored here.
  label text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- Exercises are a reusable library: not owned by a single routine. Which
-- routines an exercise appears in (and in what order) lives in
-- routine_exercises below.
create table if not exists exercises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  -- Freeform goal text shown under the name, e.g. "3 sets × 6-10 reps" or
  -- "12 mins or 150 cals" — not structured, so it fits any kind of exercise.
  subtitle text,
  created_at timestamptz not null default now()
);

create table if not exists routine_exercises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  routine_id uuid not null references routines(id) on delete cascade,
  exercise_id uuid not null references exercises(id) on delete cascade,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (routine_id, exercise_id)
);

create table if not exists cues (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  exercise_id uuid not null references exercises(id) on delete cascade,
  text text not null,
  sort_order int not null default 0,
  level int not null default 0,
  is_header boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  routine_id uuid references routines(id) on delete set null,
  performed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists exercise_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  session_id uuid not null references workout_sessions(id) on delete cascade,
  exercise_id uuid not null references exercises(id) on delete cascade,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists set_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  exercise_log_id uuid not null references exercise_logs(id) on delete cascade,
  set_number int not null,
  weight numeric,
  reps int,
  created_at timestamptz not null default now()
);

create index if not exists routine_exercises_routine_id_idx on routine_exercises(routine_id);
create index if not exists routine_exercises_exercise_id_idx on routine_exercises(exercise_id);
create index if not exists cues_exercise_id_idx on cues(exercise_id);
create index if not exists workout_sessions_routine_id_idx on workout_sessions(routine_id);
create index if not exists exercise_logs_session_id_idx on exercise_logs(session_id);
create index if not exists exercise_logs_exercise_id_idx on exercise_logs(exercise_id);
create index if not exists set_logs_exercise_log_id_idx on set_logs(exercise_log_id);

alter table routines enable row level security;
alter table exercises enable row level security;
alter table routine_exercises enable row level security;
alter table cues enable row level security;
alter table workout_sessions enable row level security;
alter table exercise_logs enable row level security;
alter table set_logs enable row level security;

create policy "owner full access" on routines
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner full access" on exercises
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner full access" on routine_exercises
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner full access" on cues
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner full access" on workout_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner full access" on exercise_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner full access" on set_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Table-level grants: RLS policies above are the real access control, but Postgres
-- still requires the `authenticated` role to hold baseline table privileges before
-- RLS is even evaluated. We deliberately do NOT grant anything to `anon` — this app
-- has no unauthenticated access, so the app-level login gate plus this omission
-- give defense in depth even if RLS were ever misconfigured.
grant usage on schema public to authenticated;
grant select, insert, update, delete on routines, exercises, routine_exercises, cues, workout_sessions, exercise_logs, set_logs to authenticated;

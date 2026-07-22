-- Gym Bro schema
-- Run this once in the Supabase SQL Editor (Dashboard > SQL Editor > New query) after creating your project.
-- Every table carries its own user_id (denormalized) so Row Level Security policies stay a simple
-- `auth.uid() = user_id` check on each table, rather than nested joins up to `days`.

create table if not exists days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists exercises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day_id uuid not null references days(id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  target_sets int,
  target_reps_low int,
  target_reps_high int,
  created_at timestamptz not null default now()
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
  day_id uuid references days(id) on delete set null,
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

create index if not exists exercises_day_id_idx on exercises(day_id);
create index if not exists cues_exercise_id_idx on cues(exercise_id);
create index if not exists workout_sessions_day_id_idx on workout_sessions(day_id);
create index if not exists exercise_logs_session_id_idx on exercise_logs(session_id);
create index if not exists exercise_logs_exercise_id_idx on exercise_logs(exercise_id);
create index if not exists set_logs_exercise_log_id_idx on set_logs(exercise_log_id);

alter table days enable row level security;
alter table exercises enable row level security;
alter table cues enable row level security;
alter table workout_sessions enable row level security;
alter table exercise_logs enable row level security;
alter table set_logs enable row level security;

create policy "owner full access" on days
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner full access" on exercises
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner full access" on cues
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner full access" on workout_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner full access" on exercise_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner full access" on set_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

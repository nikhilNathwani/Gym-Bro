-- Migration: exercises become a reusable library instead of belonging to one day.
-- Run this once in the Supabase SQL Editor (Dashboard > SQL Editor > New query).
-- Non-destructive: backfills day_exercises from the existing exercises.day_id/sort_order
-- before dropping those columns, so any exercises you already created keep their day
-- assignment.

-- 1. Days: the "Day A"/"Day B" letter is now computed from position, not stored.
--    `name` becomes an optional subtitle — renamed to `label` to make that clear.
alter table days rename column name to label;
alter table days alter column label drop not null;

-- 2. Join table: which exercises are assigned to which days, in what order.
create table if not exists day_exercises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day_id uuid not null references days(id) on delete cascade,
  exercise_id uuid not null references exercises(id) on delete cascade,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (day_id, exercise_id)
);

-- 3. Backfill from the existing 1:1 exercises.day_id/sort_order.
insert into day_exercises (user_id, day_id, exercise_id, sort_order)
select user_id, day_id, id, sort_order
from exercises
where day_id is not null
on conflict (day_id, exercise_id) do nothing;

-- 4. Exercises are now day-agnostic; ordering within a day lives on day_exercises.
alter table exercises drop column day_id;
alter table exercises drop column sort_order;

-- 5. Indexes.
create index if not exists day_exercises_day_id_idx on day_exercises(day_id);
create index if not exists day_exercises_exercise_id_idx on day_exercises(exercise_id);

-- 6. RLS + grants, matching the pattern every other table uses.
alter table day_exercises enable row level security;
create policy "owner full access" on day_exercises
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
grant select, insert, update, delete on day_exercises to authenticated;

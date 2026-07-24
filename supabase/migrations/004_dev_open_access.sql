-- Migration: open up DB access for solo local development/testing.
-- Run this once in the Supabase SQL Editor, after 002 and 003.
--
-- WARNING — this removes Row Level Security's real protection. Anyone with
-- your Supabase URL + anon key (already public in the client bundle) can
-- read/write every table after this runs. Fine while this only runs on your
-- laptop for personal use; MUST be reverted before deploying anywhere public.
-- Symmetric to AUTH_REQUIRED in src/lib/supabase/middleware.ts — re-lock both
-- together, using supabase/relock_rls.sql, when you're ready to go public.

-- Let unauthenticated requests (e.g. tooling with no login session) through.
grant usage on schema public to anon;
grant select, insert, update, delete on
  days, exercises, day_exercises, cues, workout_sessions, exercise_logs, set_logs
  to anon;

-- user_id defaults were auth.uid(), which is null without a session — that
-- would violate the NOT NULL constraint on insert. Point it at your single
-- account instead, so unauthenticated writes still attribute correctly.
-- (Postgres doesn't allow a bare subquery in a DEFAULT expression, hence the
-- wrapper function — a function call is fine, it's the raw `(select ...)`
-- syntax specifically that's disallowed.)
create or replace function public.dev_single_user_id() returns uuid
language sql stable
as $$ select id from auth.users limit 1 $$;

alter table days alter column user_id set default public.dev_single_user_id();
alter table exercises alter column user_id set default public.dev_single_user_id();
alter table day_exercises alter column user_id set default public.dev_single_user_id();
alter table cues alter column user_id set default public.dev_single_user_id();
alter table workout_sessions alter column user_id set default public.dev_single_user_id();
alter table exercise_logs alter column user_id set default public.dev_single_user_id();
alter table set_logs alter column user_id set default public.dev_single_user_id();

-- Replace whatever RLS policies currently exist with fully open ones. Looked
-- up dynamically (rather than a hardcoded `drop policy "owner full access"`)
-- because this project's policy naming has drifted across earlier manual
-- edits, so the literal name to drop can't be relied on — this works no
-- matter what's actually there.
do $$
declare
  pol record;
  tbl text;
begin
  foreach tbl in array array[
    'days', 'exercises', 'day_exercises', 'cues',
    'workout_sessions', 'exercise_logs', 'set_logs'
  ]
  loop
    for pol in
      select policyname from pg_policies
      where schemaname = 'public' and tablename = tbl
    loop
      execute format('drop policy %I on public.%I', pol.policyname, tbl);
    end loop;
  end loop;
end $$;

create policy "dev open access" on days for all using (true) with check (true);
create policy "dev open access" on exercises for all using (true) with check (true);
create policy "dev open access" on day_exercises for all using (true) with check (true);
create policy "dev open access" on cues for all using (true) with check (true);
create policy "dev open access" on workout_sessions for all using (true) with check (true);
create policy "dev open access" on exercise_logs for all using (true) with check (true);
create policy "dev open access" on set_logs for all using (true) with check (true);

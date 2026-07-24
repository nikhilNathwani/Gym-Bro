-- Re-lock the database before deploying anywhere public.
-- Run this in the Supabase SQL Editor, and flip AUTH_REQUIRED back to true
-- in src/lib/supabase/middleware.ts at the same time — the two are meant to
-- be flipped together. Reverses supabase/migrations/004_dev_open_access.sql.

revoke select, insert, update, delete on
  days, exercises, day_exercises, cues, workout_sessions, exercise_logs, set_logs
  from anon;
revoke usage on schema public from anon;

alter table days alter column user_id set default auth.uid();
alter table exercises alter column user_id set default auth.uid();
alter table day_exercises alter column user_id set default auth.uid();
alter table cues alter column user_id set default auth.uid();
alter table workout_sessions alter column user_id set default auth.uid();
alter table exercise_logs alter column user_id set default auth.uid();
alter table set_logs alter column user_id set default auth.uid();

drop function if exists public.dev_single_user_id();

drop policy if exists "dev open access" on days;
create policy "owner full access" on days
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "dev open access" on exercises;
create policy "owner full access" on exercises
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "dev open access" on day_exercises;
create policy "owner full access" on day_exercises
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "dev open access" on cues;
create policy "owner full access" on cues
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "dev open access" on workout_sessions;
create policy "owner full access" on workout_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "dev open access" on exercise_logs;
create policy "owner full access" on exercise_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "dev open access" on set_logs;
create policy "owner full access" on set_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

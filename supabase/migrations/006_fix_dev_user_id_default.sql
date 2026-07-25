-- Migration: fix silent insert failures introduced by 004_dev_open_access.sql.
--
-- dev_single_user_id() runs `select id from auth.users limit 1` as an
-- invoker-rights function. The anon role (used for all writes now that
-- sign-in is bypassed) has no grant on auth.users, so every insert that
-- relies on this default — starting with workout_sessions, which cascades
-- to exercise_logs/set_logs — fails with "permission denied for table
-- users". addLogEntry() swallows that error silently, so logging entries
-- looked like it worked but nothing was ever saved.
--
-- Fix: mark the function security definer (with a pinned search_path, as
-- Postgres requires for security definer functions) so it runs with the
-- definer's privileges for just this one-row lookup, instead of granting
-- anon broad SELECT on auth.users (which would expose emails/password
-- hashes to anyone holding the public anon key).

create or replace function public.dev_single_user_id() returns uuid
language sql stable security definer
set search_path = public, auth
as $$ select id from auth.users limit 1 $$;

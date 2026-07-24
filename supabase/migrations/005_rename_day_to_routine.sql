-- Migration: rename the "day" concept to "routine" throughout the schema,
-- matching the app-level rename from "Day" to "Routine".
-- Run this once in the Supabase SQL Editor, after 002, 003, and 004.
--
-- Pure renames (ALTER ... RENAME), not drop/recreate — your data is untouched.
-- RLS policies and grants stay attached across a rename automatically, so
-- nothing there needs to change.

alter table days rename to routines;

alter table day_exercises rename to routine_exercises;
alter table routine_exercises rename column day_id to routine_id;

alter table workout_sessions rename column day_id to routine_id;

-- Table renames don't rename their indexes — do that too, purely for
-- readability when inspecting the schema later. Guarded with IF EXISTS since
-- this project's object naming has drifted from schema.sql before.
alter index if exists day_exercises_day_id_idx rename to routine_exercises_routine_id_idx;
alter index if exists day_exercises_exercise_id_idx rename to routine_exercises_exercise_id_idx;
alter index if exists workout_sessions_day_id_idx rename to workout_sessions_routine_id_idx;

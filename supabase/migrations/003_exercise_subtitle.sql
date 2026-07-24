-- Migration: replace exercises.target_sets/target_reps_low/target_reps_high
-- with a single freeform `subtitle` text field (e.g. "3 sets × 6-10 reps",
-- or "12 mins or 150 cals" for non-set/rep goals).
-- Run this once in the Supabase SQL Editor, after 002_exercise_library.sql.
-- Non-destructive: backfills subtitle from the existing structured fields
-- before dropping them.

alter table exercises add column subtitle text;

update exercises
set subtitle = array_to_string(
  array_remove(
    array[
      case when target_sets is not null then target_sets::text || ' sets' else null end,
      case
        when target_reps_low is not null and target_reps_high is not null
          then target_reps_low::text || '–' || target_reps_high::text || ' reps'
        when target_reps_low is not null then target_reps_low::text || '+ reps'
        when target_reps_high is not null then 'up to ' || target_reps_high::text || ' reps'
        else null
      end
    ],
    null
  ),
  ' × '
)
where target_sets is not null or target_reps_low is not null or target_reps_high is not null;

alter table exercises drop column target_sets;
alter table exercises drop column target_reps_low;
alter table exercises drop column target_reps_high;

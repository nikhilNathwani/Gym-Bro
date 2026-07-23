-- Gym Bro seed data: your real "Day A" routine, plus one logged session so the
-- "show last time's numbers" feature has real data to render against.
-- Run this once in the Supabase SQL Editor, after schema.sql, while logged into
-- this project (assumes exactly one row in auth.users — true for this single-user app).

do $$
declare
  v_user_id uuid;
  v_day_id uuid;
  v_session_id uuid;
  v_exercise_id uuid;
  v_exercise_log_id uuid;
begin
  select id into v_user_id from auth.users limit 1;

  insert into days (user_id, name, sort_order)
  values (v_user_id, 'Day A', 0)
  returning id into v_day_id;

  insert into workout_sessions (user_id, day_id, performed_at)
  values (v_user_id, v_day_id, now() - interval '7 days')
  returning id into v_session_id;

  -- Exercise 1: Assisted Pull-ups
  insert into exercises (user_id, day_id, name, sort_order, target_sets, target_reps_low, target_reps_high)
  values (v_user_id, v_day_id, 'Assisted Pull-ups', 0, 3, 6, 10)
  returning id into v_exercise_id;

  insert into cues (user_id, exercise_id, text, sort_order, level, is_header) values
    (v_user_id, v_exercise_id, 'Chest proud', 0, 0, false),
    (v_user_id, v_exercise_id, 'Pull elbows toward ribs', 1, 0, false),
    (v_user_id, v_exercise_id, 'Think "drive elbows down"', 2, 0, false),
    (v_user_id, v_exercise_id, 'Control the lowering (2-3 sec)', 3, 0, false);

  insert into exercise_logs (user_id, session_id, exercise_id, notes)
  values (v_user_id, v_session_id, v_exercise_id, 'Felt most in arms, triceps leading into armpit')
  returning id into v_exercise_log_id;

  insert into set_logs (user_id, exercise_log_id, set_number, weight, reps) values
    (v_user_id, v_exercise_log_id, 1, 100, 10),
    (v_user_id, v_exercise_log_id, 2, 87.5, 10),
    (v_user_id, v_exercise_log_id, 3, 100, 10);

  -- Exercise 2: Seated Dumbbell Overhead Press
  insert into exercises (user_id, day_id, name, sort_order, target_sets, target_reps_low, target_reps_high)
  values (v_user_id, v_day_id, 'Seated Dumbbell Overhead Press', 1, 3, 8, 10)
  returning id into v_exercise_id;

  insert into cues (user_id, exercise_id, text, sort_order, level, is_header) values
    (v_user_id, v_exercise_id, 'Back supported', 0, 0, false),
    (v_user_id, v_exercise_id, 'Feet planted', 1, 0, false),
    (v_user_id, v_exercise_id, 'Slightly angled elbows (not flared straight out)', 2, 0, false),
    (v_user_id, v_exercise_id, 'Press up, not forward', 3, 0, false),
    (v_user_id, v_exercise_id, 'Don''t force dumbbells together at the top', 4, 0, false),
    (v_user_id, v_exercise_id, 'Controlled lowering', 5, 0, false),
    (v_user_id, v_exercise_id, 'Before pressing:', 6, 0, true),
    (v_user_id, v_exercise_id, 'Squeeze your shoulder blades lightly into the bench', 7, 1, false),
    (v_user_id, v_exercise_id, 'Brace your abs (don''t let your ribs flare up)', 8, 1, false),
    (v_user_id, v_exercise_id, 'Get the dumbbells settled at shoulder height', 9, 1, false),
    (v_user_id, v_exercise_id, 'During:', 10, 0, true),
    (v_user_id, v_exercise_id, 'Keep elbows slightly forward (not directly out to your sides)', 11, 1, false),
    (v_user_id, v_exercise_id, 'Imagine pressing the dumbbells "up and slightly inward"', 12, 1, false),
    (v_user_id, v_exercise_id, 'Don''t worry about making them touch at the top', 13, 1, false),
    (v_user_id, v_exercise_id, 'Lowering:', 14, 0, true),
    (v_user_id, v_exercise_id, 'Take 2 seconds down', 15, 1, false),
    (v_user_id, v_exercise_id, 'Don''t let the dumbbells drop into the bottom position', 16, 1, false);

  insert into exercise_logs (user_id, session_id, exercise_id, notes)
  values (v_user_id, v_session_id, v_exercise_id, 'felt easy, try 20 lb next time')
  returning id into v_exercise_log_id;

  insert into set_logs (user_id, exercise_log_id, set_number, weight, reps) values
    (v_user_id, v_exercise_log_id, 1, 10, 10),
    (v_user_id, v_exercise_log_id, 2, 15, 10),
    (v_user_id, v_exercise_log_id, 3, 15, 10);

  -- Exercise 3: Dumbbell Lateral Raises
  insert into exercises (user_id, day_id, name, sort_order, target_sets, target_reps_low, target_reps_high)
  values (v_user_id, v_day_id, 'Dumbbell Lateral Raises', 2, 3, 12, 15)
  returning id into v_exercise_id;

  insert into cues (user_id, exercise_id, text, sort_order, level, is_header) values
    (v_user_id, v_exercise_id, 'Slight bend in elbows', 0, 0, false),
    (v_user_id, v_exercise_id, 'Elbows slightly in front of your body', 1, 0, false),
    (v_user_id, v_exercise_id, 'Small forward lean', 2, 0, false),
    (v_user_id, v_exercise_id, 'Think "push elbows out," not "lift dumbbells"', 3, 0, false),
    (v_user_id, v_exercise_id, 'Stop around shoulder height', 4, 0, false),
    (v_user_id, v_exercise_id, 'Avoid shrugging', 5, 0, false);

  insert into exercise_logs (user_id, session_id, exercise_id, notes)
  values (v_user_id, v_session_id, v_exercise_id, 'right shoulder clicking lessened with forward lean at hips + lifting arms slightly more forward rather than straight to sides')
  returning id into v_exercise_log_id;

  insert into set_logs (user_id, exercise_log_id, set_number, weight, reps) values
    (v_user_id, v_exercise_log_id, 1, 5, 10),
    (v_user_id, v_exercise_log_id, 2, 5, 10),
    (v_user_id, v_exercise_log_id, 3, 5, 10);
end $$;

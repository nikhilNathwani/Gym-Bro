export type Routine = {
  id: string;
  label: string | null;
  sort_order: number;
};

export type Exercise = {
  id: string;
  name: string;
  subtitle: string | null;
};

export type SetLog = {
  id: string;
  set_number: number;
  weight: number | null;
  reps: number | null;
};

export type ExerciseLog = {
  id: string;
  notes: string | null;
  created_at: string;
  set_logs: SetLog[];
};

export type ExerciseDetail = Exercise & {
  cues: string | null;
  exercise_logs: ExerciseLog[];
};

export type RoutineExercise = {
  id: string;
  sort_order: number;
  exercise: ExerciseDetail;
};

export type RoutineDetail = Routine & {
  routine_exercises: RoutineExercise[];
};

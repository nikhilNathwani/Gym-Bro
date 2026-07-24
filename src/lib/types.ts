export type Routine = {
  id: string;
  label: string | null;
  sort_order: number;
};

export type Cue = {
  id: string;
  text: string;
  sort_order: number;
  level: number;
  is_header: boolean;
};

export type Exercise = {
  id: string;
  name: string;
  subtitle: string | null;
};

export type ExerciseWithCues = Exercise & {
  cues: Cue[];
};

export type RoutineExercise = {
  id: string;
  sort_order: number;
  exercise: Exercise;
};

export type RoutineDetail = Routine & {
  routine_exercises: RoutineExercise[];
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

export type ExerciseDetail = ExerciseWithCues & {
  exercise_logs: ExerciseLog[];
};

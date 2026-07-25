import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { RoutineDetail } from "@/lib/types";
import { routineLetter } from "@/lib/routine-letter";
import { RoutineView } from "./RoutineView";

export default async function RoutinePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const [
    { data: routine, error: routineError },
    { data: allRoutines },
    { data: allExercises },
  ] = await Promise.all([
    supabase
      .from("routines")
      .select(
        "id, label, sort_order, routine_exercises(id, sort_order, exercise:exercises(id, name, subtitle, cues, exercise_logs(id, notes, created_at, set_logs(id, set_number, weight, reps))))",
      )
      .eq("id", id)
      .order("sort_order", { referencedTable: "routine_exercises" })
      .maybeSingle<RoutineDetail>(),
    supabase
      .from("routines")
      .select("id")
      .order("sort_order")
      .returns<{ id: string }[]>(),
    supabase
      .from("exercises")
      .select("id, name")
      .order("name")
      .returns<{ id: string; name: string }[]>(),
  ]);

  // A real query error (e.g. a schema migration hasn't been applied yet)
  // looks identical to "no such routine" unless we check for it explicitly —
  // surface it instead of showing a misleading 404.
  if (routineError) {
    throw new Error(`Failed to load routine ${id}: ${routineError.message}`);
  }
  if (!routine) {
    notFound();
  }

  const index = allRoutines?.findIndex((r) => r.id === id) ?? 0;
  const assignedIds = new Set(
    routine.routine_exercises.map((re) => re.exercise.id),
  );
  const unassignedExercises = (allExercises ?? []).filter(
    (e) => !assignedIds.has(e.id),
  );

  // Nested ordering across a multi-level embed (routine_exercises -> exercise
  // -> exercise_logs -> set_logs) isn't reliable with Supabase's query
  // builder, so sort in JS instead: most recent log first, sets in order.
  const sortedRoutine: RoutineDetail = {
    ...routine,
    routine_exercises: routine.routine_exercises.map((re) => ({
      ...re,
      exercise: {
        ...re.exercise,
        exercise_logs: [...re.exercise.exercise_logs]
          .sort((a, b) => b.created_at.localeCompare(a.created_at))
          .map((log) => ({
            ...log,
            set_logs: [...log.set_logs].sort(
              (a, b) => a.set_number - b.set_number,
            ),
          })),
      },
    })),
  };

  return (
    <RoutineView
      routine={sortedRoutine}
      letter={routineLetter(index)}
      unassignedExercises={unassignedExercises}
    />
  );
}

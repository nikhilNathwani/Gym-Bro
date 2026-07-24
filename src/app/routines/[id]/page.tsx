import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { RoutineDetail } from "@/lib/types";
import { routineLetter } from "@/lib/routine-letter";
import {
  moveExerciseInRoutine,
  removeExerciseFromRoutine,
  updateRoutineLabel,
} from "./actions";
import { AssignExercisePicker } from "./AssignExercisePicker";
import { DeleteRoutineButton } from "./DeleteRoutineButton";

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
        "id, label, sort_order, routine_exercises(id, sort_order, exercise:exercises(id, name, subtitle))",
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

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-8">
      <div className="border-foreground flex items-center justify-between border-b pb-4">
        <div className="flex items-center gap-3">
          <Link href="/" className="text-lg">
            ←
          </Link>
          <h1 className="text-2xl">{routineLetter(index)}</h1>
        </div>
        <DeleteRoutineButton routineId={routine.id} />
      </div>

      <form action={updateRoutineLabel} className="flex flex-col gap-2">
        <input type="hidden" name="id" value={routine.id} />
        <label className="text-sm font-medium" htmlFor="label">
          Title
        </label>
        <div className="flex gap-2">
          <input
            id="label"
            name="label"
            type="text"
            defaultValue={routine.label ?? ""}
            placeholder="e.g. Vertical Push/Pull"
            className="border-foreground bg-background w-full border px-3 py-2 text-base outline-none"
          />
          <button
            type="submit"
            className="border-foreground active:bg-foreground active:text-background border px-3 py-2 text-sm font-medium"
          >
            Save
          </button>
        </div>
      </form>

      <div className="flex flex-col gap-4">
        {routine.routine_exercises.map((re, i) => (
          <div key={re.id} className="border-foreground border">
            <div className="border-foreground flex items-stretch border-b">
              <Link
                href={`/exercises/${re.exercise.id}`}
                className="flex flex-1 flex-col justify-center gap-0.5 px-5 py-4"
              >
                <span className="text-lg font-medium">{re.exercise.name}</span>
                {re.exercise.subtitle && (
                  <span className="text-foreground text-sm">
                    {re.exercise.subtitle}
                  </span>
                )}
              </Link>
              <div className="border-foreground flex flex-col border-l">
                <form action={moveExerciseInRoutine} className="flex-1">
                  <input type="hidden" name="routineExerciseId" value={re.id} />
                  <input type="hidden" name="routineId" value={routine.id} />
                  <input type="hidden" name="direction" value="up" />
                  <button
                    type="submit"
                    disabled={i === 0}
                    aria-label="Move exercise up"
                    className="border-foreground active:bg-foreground active:text-background flex h-full w-10 items-center justify-center border-b disabled:opacity-30"
                  >
                    ↑
                  </button>
                </form>
                <form action={moveExerciseInRoutine} className="flex-1">
                  <input type="hidden" name="routineExerciseId" value={re.id} />
                  <input type="hidden" name="routineId" value={routine.id} />
                  <input type="hidden" name="direction" value="down" />
                  <button
                    type="submit"
                    disabled={i === routine.routine_exercises.length - 1}
                    aria-label="Move exercise down"
                    className="active:bg-foreground active:text-background flex h-full w-10 items-center justify-center disabled:opacity-30"
                  >
                    ↓
                  </button>
                </form>
              </div>
            </div>

            <form
              action={removeExerciseFromRoutine}
              className="border-foreground border-t px-5 py-3"
            >
              <input type="hidden" name="routineExerciseId" value={re.id} />
              <input type="hidden" name="routineId" value={routine.id} />
              <button
                type="submit"
                className="text-foreground text-xs underline"
              >
                Remove from this routine
              </button>
            </form>
          </div>
        ))}
        {routine.routine_exercises.length === 0 && (
          <p className="text-foreground">No exercises yet — add one below.</p>
        )}
      </div>

      <AssignExercisePicker
        routineId={routine.id}
        exercises={unassignedExercises}
      />

      <Link
        href={`/exercises/new?routineId=${routine.id}`}
        className="border-foreground active:bg-foreground active:text-background border px-4 py-3 text-center text-sm font-medium"
      >
        + Create new exercise for this routine
      </Link>
    </div>
  );
}

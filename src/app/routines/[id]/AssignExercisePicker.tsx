"use client";

import { useState } from "react";
import { createExercise } from "../../exercises/actions";
import { addExerciseToRoutine } from "./actions";

type ExerciseOption = { id: string; name: string };

export function AssignExercisePicker({
  routineId,
  exercises,
}: {
  routineId: string;
  exercises: ExerciseOption[];
}) {
  const [query, setQuery] = useState("");
  const trimmed = query.trim();
  const filtered = trimmed
    ? exercises.filter((e) =>
        e.name.toLowerCase().includes(trimmed.toLowerCase()),
      )
    : [];
  const hasExactMatch = filtered.some(
    (e) => e.name.toLowerCase() === trimmed.toLowerCase(),
  );

  return (
    <div className="border-foreground flex flex-col gap-3 border p-4">
      <label className="text-sm font-medium" htmlFor="exercise-search">
        + Add exercise
      </label>
      <input
        id="exercise-search"
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Search or create an exercise…"
        className="border-foreground bg-background w-full border px-3 py-2 text-base outline-none"
      />
      {trimmed && (
        <div className="border-foreground flex flex-col border">
          {filtered.map((exercise, i) => (
            <form
              key={exercise.id}
              action={addExerciseToRoutine}
              className={`flex items-center justify-between px-3 py-2 ${
                i > 0 ? "border-foreground border-t" : ""
              }`}
            >
              <input type="hidden" name="routineId" value={routineId} />
              <input type="hidden" name="exerciseId" value={exercise.id} />
              <span className="text-sm">{exercise.name}</span>
              <button
                type="submit"
                className="border-foreground active:bg-foreground active:text-background border px-2 py-1 text-xs font-medium"
              >
                Add
              </button>
            </form>
          ))}
          {!hasExactMatch && (
            <form
              action={createExercise}
              className={`flex items-center justify-between px-3 py-2 ${
                filtered.length > 0 ? "border-foreground border-t" : ""
              }`}
            >
              <input type="hidden" name="routineId" value={routineId} />
              <input type="hidden" name="name" value={trimmed} />
              <span className="text-sm">
                Create <span className="font-medium">“{trimmed}”</span>
              </span>
              <button
                type="submit"
                className="border-foreground active:bg-foreground active:text-background border px-2 py-1 text-xs font-medium"
              >
                Create
              </button>
            </form>
          )}
        </div>
      )}
    </div>
  );
}

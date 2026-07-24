"use client";

import { useState } from "react";
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
  const filtered = exercises.filter((e) =>
    e.name.toLowerCase().includes(query.trim().toLowerCase()),
  );

  return (
    <div className="border-foreground flex flex-col gap-3 border p-4">
      <label className="text-sm font-medium" htmlFor="exercise-search">
        + Add existing exercise
      </label>
      <input
        id="exercise-search"
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Search exercises…"
        className="border-foreground bg-background w-full border px-3 py-2 text-base outline-none"
      />
      {query && (
        <div className="border-foreground flex flex-col border">
          {filtered.length > 0 ? (
            filtered.map((exercise, i) => (
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
            ))
          ) : (
            <p className="text-foreground px-3 py-2 text-sm">No matches.</p>
          )}
        </div>
      )}
    </div>
  );
}

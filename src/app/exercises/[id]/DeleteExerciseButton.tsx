"use client";

import { deleteExercise } from "../actions";

export function DeleteExerciseButton({ exerciseId }: { exerciseId: string }) {
  return (
    <form
      action={deleteExercise}
      onSubmit={(e) => {
        if (
          !confirm(
            "Delete this exercise? This removes it from every routine and deletes its log history. This cannot be undone.",
          )
        ) {
          e.preventDefault();
        }
      }}
    >
      <input type="hidden" name="id" value={exerciseId} />
      <button
        type="submit"
        className="border-foreground active:bg-foreground active:text-background border px-3 py-1.5 text-xs font-medium"
      >
        Delete exercise
      </button>
    </form>
  );
}

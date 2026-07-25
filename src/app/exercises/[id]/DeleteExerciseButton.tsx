"use client";

import { deleteExercise } from "../actions";

export function DeleteExerciseButton({ exerciseId }: { exerciseId: string }) {
  return (
    <form
      action={deleteExercise}
      className="contents"
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
      <button type="submit" className="text-foreground text-xs underline">
        Delete exercise
      </button>
    </form>
  );
}

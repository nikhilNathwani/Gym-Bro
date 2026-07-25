"use client";

import { deleteRoutine } from "./actions";

export function DeleteRoutineButton({ routineId }: { routineId: string }) {
  return (
    <form
      action={deleteRoutine}
      className="contents"
      onSubmit={(e) => {
        if (!confirm("Delete this routine? This cannot be undone.")) {
          e.preventDefault();
        }
      }}
    >
      <input type="hidden" name="id" value={routineId} />
      <button type="submit" className="text-foreground text-xs underline">
        Delete routine
      </button>
    </form>
  );
}

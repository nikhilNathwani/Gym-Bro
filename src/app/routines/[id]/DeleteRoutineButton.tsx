"use client";

import { deleteRoutine } from "./actions";

export function DeleteRoutineButton({ routineId }: { routineId: string }) {
  return (
    <form
      action={deleteRoutine}
      onSubmit={(e) => {
        if (!confirm("Delete this routine? This cannot be undone.")) {
          e.preventDefault();
        }
      }}
    >
      <input type="hidden" name="id" value={routineId} />
      <button
        type="submit"
        className="border-foreground active:bg-foreground active:text-background border px-3 py-1.5 text-xs font-medium"
      >
        Delete routine
      </button>
    </form>
  );
}

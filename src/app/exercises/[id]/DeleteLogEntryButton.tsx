"use client";

import { deleteLogEntry } from "../actions";

export function DeleteLogEntryButton({
  exerciseLogId,
  exerciseId,
}: {
  exerciseLogId: string;
  exerciseId: string;
}) {
  return (
    <form
      action={deleteLogEntry}
      className="contents"
      onSubmit={(e) => {
        if (!confirm("Delete this logged session? This cannot be undone.")) {
          e.preventDefault();
        }
      }}
    >
      <input type="hidden" name="exerciseLogId" value={exerciseLogId} />
      <input type="hidden" name="exerciseId" value={exerciseId} />
      <button type="submit" className="text-foreground text-xs underline">
        Delete
      </button>
    </form>
  );
}

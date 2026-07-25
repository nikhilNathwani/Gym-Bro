"use client";

import { useState, useTransition } from "react";
import { updateLogEntry } from "../actions";
import { DeleteLogEntryButton } from "./DeleteLogEntryButton";
import { LogSummary } from "./LogSummary";
import { SetFieldsEditor } from "./SetFieldsEditor";
import type { ExerciseLog } from "@/lib/types";

export function HistoryEntry({
  log,
  exerciseId,
  canEdit,
}: {
  log: ExerciseLog;
  exerciseId: string;
  canEdit: boolean;
}) {
  const [isEditing, setIsEditing] = useState(false);
  const [isPending, startTransition] = useTransition();

  if (!canEdit || !isEditing) {
    return (
      <div className="border-foreground border p-3">
        {canEdit && (
          <div className="flex justify-end gap-3">
            <button
              type="button"
              onClick={() => setIsEditing(true)}
              className="text-foreground text-xs underline"
            >
              Edit
            </button>
            <DeleteLogEntryButton
              exerciseLogId={log.id}
              exerciseId={exerciseId}
            />
          </div>
        )}
        <div className={canEdit ? "mt-2" : ""}>
          <LogSummary log={log} />
        </div>
      </div>
    );
  }

  const initialWeight = log.set_logs.map((s) => s.weight ?? "").join(",");
  const initialReps = log.set_logs.map((s) => s.reps ?? "").join(",");

  return (
    <form
      className="border-foreground flex flex-col gap-3 border p-3"
      onSubmit={(e) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        startTransition(async () => {
          await updateLogEntry(formData);
          setIsEditing(false);
        });
      }}
    >
      <input type="hidden" name="exerciseLogId" value={log.id} />
      <input type="hidden" name="exerciseId" value={exerciseId} />

      <SetFieldsEditor
        initialWeight={initialWeight}
        initialReps={initialReps}
      />

      <textarea
        name="notes"
        defaultValue={log.notes ?? ""}
        placeholder="Notes — how did it feel?"
        rows={2}
        className="border-foreground bg-background w-full border px-3 py-2 text-base outline-none"
      />

      <div className="flex gap-2">
        <button
          type="submit"
          disabled={isPending}
          className="text-background bg-foreground border-foreground active:bg-background active:text-foreground flex-1 border px-3 py-2 text-sm font-medium disabled:opacity-50"
        >
          Save
        </button>
        <button
          type="button"
          onClick={() => setIsEditing(false)}
          className="border-foreground active:bg-foreground active:text-background flex-1 border px-3 py-2 text-sm font-medium"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}

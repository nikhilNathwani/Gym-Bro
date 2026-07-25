"use client";

import { addLogEntry } from "../actions";
import { SetFieldsEditor } from "./SetFieldsEditor";
import type { SetLog } from "@/lib/types";

export function LogEntryForm({
  exerciseId,
  previousSets = [],
  bordered = true,
}: {
  exerciseId: string;
  previousSets?: SetLog[];
  bordered?: boolean;
}) {
  return (
    <form
      action={addLogEntry}
      className={
        bordered
          ? "border-foreground flex flex-col gap-3 border p-4"
          : "flex flex-col gap-3"
      }
    >
      <input type="hidden" name="exerciseId" value={exerciseId} />
      <span className="text-sm font-medium">+ Log today</span>

      <SetFieldsEditor previousSets={previousSets} />

      <textarea
        name="notes"
        placeholder="Notes — how did it feel?"
        rows={2}
        className="border-foreground bg-background w-full border px-3 py-2 text-base outline-none"
      />

      <button
        type="submit"
        className="text-background bg-foreground border-foreground active:bg-background active:text-foreground w-full border px-4 py-2 text-sm font-medium"
      >
        Save entry
      </button>
    </form>
  );
}

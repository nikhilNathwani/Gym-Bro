"use client";

import { useState } from "react";
import { addLogEntry } from "../actions";

const DEFAULT_SET_COUNT = 3;

export function LogEntryForm({ exerciseId }: { exerciseId: string }) {
  const [setCount, setSetCount] = useState(DEFAULT_SET_COUNT);

  return (
    <form
      action={addLogEntry}
      className="border-foreground flex flex-col gap-3 border p-4"
    >
      <input type="hidden" name="exerciseId" value={exerciseId} />
      <span className="text-sm font-medium">+ Log today</span>

      <div className="flex flex-col gap-2">
        {Array.from({ length: setCount }).map((_, i) => (
          <div key={i} className="flex items-center gap-2">
            <span className="text-foreground w-10 shrink-0 text-sm">
              Set {i + 1}
            </span>
            <input
              name="weight"
              type="number"
              inputMode="decimal"
              step="0.5"
              placeholder="Weight"
              className="border-foreground bg-background w-full border px-3 py-2 text-base outline-none"
            />
            <input
              name="reps"
              type="number"
              inputMode="numeric"
              placeholder="Reps"
              className="border-foreground bg-background w-full border px-3 py-2 text-base outline-none"
            />
          </div>
        ))}
      </div>

      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => setSetCount((n) => n + 1)}
          className="border-foreground active:bg-foreground active:text-background border px-2 py-1 text-xs font-medium"
        >
          + Add set
        </button>
        {setCount > 1 && (
          <button
            type="button"
            onClick={() => setSetCount((n) => n - 1)}
            className="border-foreground active:bg-foreground active:text-background border px-2 py-1 text-xs font-medium"
          >
            − Remove set
          </button>
        )}
      </div>

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

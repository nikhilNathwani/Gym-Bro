"use client";

import { useState, useTransition } from "react";
import { updateExercise } from "../actions";

export function EditableTarget({
  exerciseId,
  initialSubtitle,
  isEditing,
}: {
  exerciseId: string;
  initialSubtitle: string;
  isEditing: boolean;
}) {
  const [target, setTarget] = useState(initialSubtitle);
  const [, startTransition] = useTransition();

  function save(next: string) {
    const formData = new FormData();
    formData.set("id", exerciseId);
    formData.set("subtitle", next);
    startTransition(() => {
      updateExercise(formData);
    });
  }

  if (!isEditing) {
    return target ? (
      <p className="text-sm">
        <span className="text-foreground font-medium">Target: </span>
        {target}
      </p>
    ) : null;
  }

  return (
    <div className="flex flex-col gap-1">
      <span className="text-sm font-medium">Target</span>
      <input
        value={target}
        onChange={(e) => setTarget(e.target.value)}
        onBlur={() => save(target)}
        placeholder="e.g. 3 sets × 6–10 reps"
        aria-label="Target"
        className="border-foreground bg-background placeholder:text-foreground w-full border px-3 py-2 text-sm outline-none placeholder:opacity-40"
      />
    </div>
  );
}

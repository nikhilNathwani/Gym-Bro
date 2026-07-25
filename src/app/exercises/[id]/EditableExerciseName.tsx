"use client";

import { useState, useTransition } from "react";
import { updateExercise } from "../actions";

export function EditableExerciseName({
  exerciseId,
  initialName,
}: {
  exerciseId: string;
  initialName: string;
}) {
  const [name, setName] = useState(initialName);
  const [, startTransition] = useTransition();

  function save(next: string) {
    if (!next.trim()) {
      setName(initialName);
      return;
    }
    const formData = new FormData();
    formData.set("id", exerciseId);
    formData.set("name", next);
    startTransition(() => {
      updateExercise(formData);
    });
  }

  return (
    <input
      value={name}
      onChange={(e) => setName(e.target.value)}
      onBlur={() => save(name)}
      aria-label="Exercise name"
      className="focus:border-foreground -mx-2 w-full truncate border border-transparent bg-transparent px-2 py-1 text-2xl outline-none"
    />
  );
}

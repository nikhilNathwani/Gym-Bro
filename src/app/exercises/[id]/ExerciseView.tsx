"use client";

import { useState } from "react";
import type { ExerciseDetail } from "@/lib/types";
import { EditableCues } from "./EditableCues";
import { EditableTarget } from "./EditableTarget";
import { HistoryEntry } from "./HistoryEntry";
import { LogEntryForm } from "./LogEntryForm";
import { StickyExerciseHeader } from "./StickyExerciseHeader";

export function ExerciseView({
  exercise,
  backHref,
  backLabel,
}: {
  exercise: ExerciseDetail;
  backHref: string;
  backLabel: string;
}) {
  const [isEditing, setIsEditing] = useState(false);

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-8">
      <StickyExerciseHeader
        exerciseId={exercise.id}
        initialName={exercise.name}
        isEditing={isEditing}
        onToggleEditing={() => setIsEditing((v) => !v)}
        backHref={backHref}
        backLabel={backLabel}
      />

      <EditableTarget
        exerciseId={exercise.id}
        initialSubtitle={exercise.subtitle ?? ""}
        isEditing={isEditing}
      />

      <EditableCues
        exerciseId={exercise.id}
        initialCues={exercise.cues ?? ""}
        canEdit={isEditing}
      />

      <div className="flex flex-col gap-3">
        <span className="text-sm font-medium">History</span>
        {exercise.exercise_logs.length > 0 ? (
          <div className="flex flex-col gap-3">
            {exercise.exercise_logs.map((log) => (
              <HistoryEntry
                key={log.id}
                log={log}
                exerciseId={exercise.id}
                canEdit={isEditing}
              />
            ))}
          </div>
        ) : (
          <p className="text-foreground">No logged sessions yet.</p>
        )}
      </div>

      <LogEntryForm
        exerciseId={exercise.id}
        previousSets={exercise.exercise_logs[0]?.set_logs}
      />
    </div>
  );
}

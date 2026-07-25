"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import type { RoutineDetail } from "@/lib/types";
import { ArrowDownIcon, ArrowLeftIcon, ArrowUpIcon } from "@/components/icons";
import { LogEntryForm } from "../../exercises/[id]/LogEntryForm";
import { LogSummary } from "../../exercises/[id]/LogSummary";
import {
  moveExerciseInRoutine,
  removeExerciseFromRoutine,
  updateRoutineLabel,
} from "./actions";
import { AssignExercisePicker } from "./AssignExercisePicker";
import { DeleteRoutineButton } from "./DeleteRoutineButton";

type ExerciseOption = { id: string; name: string };

export function RoutineView({
  routine,
  letter,
  unassignedExercises,
}: {
  routine: RoutineDetail;
  letter: string;
  unassignedExercises: ExerciseOption[];
}) {
  const [isEditing, setIsEditing] = useState(false);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const expandedCardRef = useRef<HTMLDivElement>(null);

  const title = routine.label ? `${letter} - ${routine.label}` : letter;
  const exerciseBackQuery = `?back=${encodeURIComponent(`/routines/${routine.id}`)}&backLabel=${encodeURIComponent(letter)}`;

  // Tap anywhere outside the expanded card collapses it.
  useEffect(() => {
    if (!expandedId) return;
    function handlePointerDown(e: PointerEvent) {
      const target = e.target as Node;
      if (expandedCardRef.current?.contains(target)) return;
      setExpandedId(null);
    }
    document.addEventListener("pointerdown", handlePointerDown);
    return () => document.removeEventListener("pointerdown", handlePointerDown);
  }, [expandedId]);

  useEffect(() => {
    if (!expandedId) return;
    expandedCardRef.current?.scrollIntoView({
      behavior: "smooth",
      block: "start",
    });
  }, [expandedId]);

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-8">
      <div>
        <Link
          href="/"
          className="text-foreground flex items-center gap-1 pb-2 text-sm"
        >
          <ArrowLeftIcon className="h-4 w-4" />
          All routines
        </Link>
        <div className="border-foreground border-b pb-4">
          <h1 className="w-full truncate text-2xl">{title}</h1>
          <div className="mt-1 flex items-center gap-3">
            <button
              type="button"
              onClick={() => {
                setIsEditing((v) => !v);
                setExpandedId(null);
              }}
              className="text-foreground text-xs underline"
            >
              {isEditing ? "Done" : "Edit"}
            </button>
            <DeleteRoutineButton routineId={routine.id} />
          </div>
        </div>
      </div>

      {isEditing && (
        <form action={updateRoutineLabel} className="flex flex-col gap-2">
          <input type="hidden" name="id" value={routine.id} />
          <label className="text-sm font-medium" htmlFor="label">
            Title
          </label>
          <div className="flex gap-2">
            <input
              id="label"
              name="label"
              type="text"
              defaultValue={routine.label ?? ""}
              placeholder="e.g. Vertical Push/Pull"
              className="border-foreground bg-background w-full border px-3 py-2 text-base outline-none"
            />
            <button
              type="submit"
              className="border-foreground active:bg-foreground active:text-background border px-3 py-2 text-sm font-medium"
            >
              Save
            </button>
          </div>
        </form>
      )}

      <div className="flex flex-col gap-4">
        {routine.routine_exercises.map((re, i) => {
          const exercise = re.exercise;

          if (isEditing) {
            return (
              <div key={re.id} className="border-foreground border">
                <div className="border-foreground flex items-stretch border-b">
                  <Link
                    href={`/exercises/${exercise.id}${exerciseBackQuery}`}
                    className="flex flex-1 flex-col justify-center gap-0.5 px-5 py-4"
                  >
                    <span className="text-lg font-medium">{exercise.name}</span>
                  </Link>
                  <div className="border-foreground flex flex-col border-l">
                    <form action={moveExerciseInRoutine} className="flex-1">
                      <input
                        type="hidden"
                        name="routineExerciseId"
                        value={re.id}
                      />
                      <input
                        type="hidden"
                        name="routineId"
                        value={routine.id}
                      />
                      <input type="hidden" name="direction" value="up" />
                      <button
                        type="submit"
                        disabled={i === 0}
                        aria-label="Move exercise up"
                        className="border-foreground active:bg-foreground active:text-background flex h-full w-10 items-center justify-center border-b disabled:opacity-30"
                      >
                        <ArrowUpIcon className="h-4 w-4" />
                      </button>
                    </form>
                    <form action={moveExerciseInRoutine} className="flex-1">
                      <input
                        type="hidden"
                        name="routineExerciseId"
                        value={re.id}
                      />
                      <input
                        type="hidden"
                        name="routineId"
                        value={routine.id}
                      />
                      <input type="hidden" name="direction" value="down" />
                      <button
                        type="submit"
                        disabled={i === routine.routine_exercises.length - 1}
                        aria-label="Move exercise down"
                        className="active:bg-foreground active:text-background flex h-full w-10 items-center justify-center disabled:opacity-30"
                      >
                        <ArrowDownIcon className="h-4 w-4" />
                      </button>
                    </form>
                  </div>
                </div>

                <form
                  action={removeExerciseFromRoutine}
                  className="border-foreground border-t px-5 py-3"
                >
                  <input type="hidden" name="routineExerciseId" value={re.id} />
                  <input type="hidden" name="routineId" value={routine.id} />
                  <button
                    type="submit"
                    className="text-foreground text-xs underline"
                  >
                    Remove from this routine
                  </button>
                </form>
              </div>
            );
          }

          const isExpanded = expandedId === exercise.id;
          const lastLog = exercise.exercise_logs[0];

          return (
            <div
              key={re.id}
              ref={isExpanded ? expandedCardRef : null}
              className="border-foreground border"
            >
              <button
                type="button"
                onClick={() =>
                  setExpandedId((prev) =>
                    prev === exercise.id ? null : exercise.id,
                  )
                }
                className="active:bg-foreground active:text-background flex w-full items-center justify-between gap-2 px-5 py-4 text-left"
              >
                <span className="text-lg font-medium">{exercise.name}</span>
                {isExpanded ? (
                  <ArrowUpIcon className="h-4 w-4 shrink-0" />
                ) : (
                  <ArrowDownIcon className="h-4 w-4 shrink-0" />
                )}
              </button>

              {isExpanded && (
                <div className="border-foreground flex flex-col gap-4 border-t p-4">
                  <Link
                    href={`/exercises/${exercise.id}${exerciseBackQuery}`}
                    className="text-foreground text-xs underline"
                  >
                    Open full exercise page
                  </Link>

                  {exercise.subtitle && (
                    <p className="text-sm">
                      <span className="text-foreground font-medium">
                        Target:{" "}
                      </span>
                      {exercise.subtitle}
                    </p>
                  )}

                  {exercise.cues && (
                    <div className="flex flex-col gap-1">
                      <span className="text-sm font-medium">Cues</span>
                      <p className="border-foreground max-h-[7.375rem] overflow-y-auto border px-3 py-2 text-sm whitespace-pre-wrap">
                        {exercise.cues}
                      </p>
                    </div>
                  )}

                  {lastLog && (
                    <div className="flex flex-col gap-1">
                      <span className="text-sm font-medium">Last logged</span>
                      <LogSummary log={lastLog} />
                    </div>
                  )}

                  <LogEntryForm
                    exerciseId={exercise.id}
                    previousSets={lastLog?.set_logs}
                    bordered={false}
                  />
                </div>
              )}
            </div>
          );
        })}
        {routine.routine_exercises.length === 0 && (
          <p className="text-foreground">No exercises yet — add one below.</p>
        )}
      </div>

      <AssignExercisePicker
        routineId={routine.id}
        exercises={unassignedExercises}
      />
    </div>
  );
}

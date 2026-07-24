"use client";

import Link from "next/link";
import { useState } from "react";
import type { Exercise } from "@/lib/types";

export function ExerciseLibraryList({ exercises }: { exercises: Exercise[] }) {
  const [query, setQuery] = useState("");
  const filtered = exercises.filter((e) =>
    e.name.toLowerCase().includes(query.trim().toLowerCase()),
  );

  return (
    <div className="flex flex-col gap-4">
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Search exercises…"
        className="border-foreground bg-background w-full border px-3 py-2 text-base outline-none"
      />
      <div className="flex flex-col gap-3">
        {filtered.length > 0 ? (
          filtered.map((exercise) => (
            <Link
              key={exercise.id}
              href={`/exercises/${exercise.id}`}
              className="border-foreground active:bg-foreground active:text-background flex flex-col gap-0.5 border px-5 py-4"
            >
              <span className="text-lg font-medium">{exercise.name}</span>
              {exercise.subtitle && (
                <span className="text-foreground text-sm">
                  {exercise.subtitle}
                </span>
              )}
            </Link>
          ))
        ) : (
          <p className="text-foreground">
            {exercises.length === 0
              ? "No exercises yet — create one below."
              : "No matches."}
          </p>
        )}
      </div>
    </div>
  );
}

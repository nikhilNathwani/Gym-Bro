import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Exercise } from "@/lib/types";

export default async function DayPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: day } = await supabase
    .from("days")
    .select(
      "id, name, exercises(id, name, sort_order, target_sets, target_reps_low, target_reps_high, cues(id, text, sort_order, level, is_header))",
    )
    .eq("id", id)
    .order("sort_order", { referencedTable: "exercises" })
    .order("sort_order", { referencedTable: "exercises.cues" })
    .maybeSingle<{ id: string; name: string; exercises: Exercise[] }>();

  if (!day) {
    notFound();
  }

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 bg-neutral-950 px-4 py-8 text-neutral-100">
      <div className="flex items-center gap-3">
        <Link href="/" className="text-neutral-500">
          ←
        </Link>
        <h1 className="text-2xl font-semibold">{day.name}</h1>
      </div>

      <div className="flex flex-col gap-4">
        {day.exercises.map((exercise, i) => (
          <details
            key={exercise.id}
            className="rounded-2xl bg-neutral-900 shadow"
            open={i === 0}
          >
            <summary className="cursor-pointer list-none px-5 py-4">
              <div className="flex items-baseline justify-between">
                <span className="text-lg font-medium">{exercise.name}</span>
              </div>
              <span className="text-sm text-neutral-500">
                {exercise.target_sets} sets × {exercise.target_reps_low}–
                {exercise.target_reps_high} reps
              </span>
            </summary>

            {exercise.cues.length > 0 && (
              <ul className="flex flex-col gap-1.5 px-5 pb-5 pt-1 text-sm text-neutral-300">
                {exercise.cues.map((cue) => (
                  <li
                    key={cue.id}
                    className={cue.level > 0 ? "ml-5" : ""}
                  >
                    {cue.is_header ? (
                      <span className="font-medium text-neutral-200">
                        {cue.text}
                      </span>
                    ) : (
                      <>
                        <span className="text-neutral-600">
                          {cue.level > 0 ? "– " : "• "}
                        </span>
                        {cue.text}
                      </>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </details>
        ))}
      </div>
    </div>
  );
}

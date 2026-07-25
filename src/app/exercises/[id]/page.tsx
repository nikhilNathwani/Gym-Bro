import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { ExerciseDetail } from "@/lib/types";
import { ExerciseView } from "./ExerciseView";

export default async function ExercisePage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ back?: string; backLabel?: string }>;
}) {
  const { id } = await params;
  const { back, backLabel } = await searchParams;
  const supabase = await createClient();

  const { data: exercise, error: exerciseError } = await supabase
    .from("exercises")
    .select(
      "id, name, subtitle, cues, exercise_logs(id, notes, created_at, set_logs(id, set_number, weight, reps))",
    )
    .eq("id", id)
    .order("created_at", {
      referencedTable: "exercise_logs",
      ascending: false,
    })
    .order("set_number", { referencedTable: "exercise_logs.set_logs" })
    .maybeSingle<ExerciseDetail>();

  // A real query error (e.g. a schema migration hasn't been applied yet)
  // looks identical to "no such exercise" unless we check for it explicitly —
  // surface it instead of showing a misleading 404.
  if (exerciseError) {
    throw new Error(`Failed to load exercise ${id}: ${exerciseError.message}`);
  }
  if (!exercise) {
    notFound();
  }

  // `back` comes from the query string — only trust it as an internal path
  // (guards against it being used as an open redirect to an external URL).
  const safeBackHref = back?.startsWith("/") ? back : "/exercises";

  return (
    <ExerciseView
      exercise={exercise}
      backHref={safeBackHref}
      backLabel={backLabel ?? "All exercises"}
    />
  );
}

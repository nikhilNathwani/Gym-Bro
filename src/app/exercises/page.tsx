import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { ExerciseLibraryList } from "./ExerciseLibraryList";
import type { Exercise } from "@/lib/types";

export default async function ExercisesPage() {
  const supabase = await createClient();
  const { data: exercises } = await supabase
    .from("exercises")
    .select("id, name, subtitle")
    .order("name")
    .returns<Exercise[]>();

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-8">
      <div className="border-foreground flex items-center gap-3 border-b pb-4">
        <Link href="/" className="text-lg">
          ←
        </Link>
        <h1 className="text-2xl">Exercises</h1>
      </div>

      <ExerciseLibraryList exercises={exercises ?? []} />

      <Link
        href="/exercises/new"
        className="border-foreground active:bg-foreground active:text-background border px-4 py-3 text-center text-sm font-medium"
      >
        + New exercise
      </Link>
    </div>
  );
}

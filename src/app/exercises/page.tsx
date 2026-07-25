import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { ArrowLeftIcon } from "@/components/icons";
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
      <div>
        <Link
          href="/"
          className="text-foreground flex items-center gap-1 pb-2 text-sm"
        >
          <ArrowLeftIcon className="h-4 w-4" />
          Gym Bro
        </Link>
        <h1 className="border-foreground border-b pb-4 text-2xl">Exercises</h1>
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

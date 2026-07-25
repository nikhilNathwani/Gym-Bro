import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { createRoutine, logout } from "./actions";
import { routineLetter } from "@/lib/routine-letter";
import type { Routine } from "@/lib/types";

export default async function Home({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  const supabase = await createClient();

  const { data: routines } = await supabase
    .from("routines")
    .select("id, label, sort_order")
    .order("sort_order")
    .returns<Routine[]>();

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-8">
      <div className="border-foreground flex items-center justify-between border-b pb-4">
        <h1 className="text-2xl">Gym Bro</h1>
        <div className="flex items-center gap-3">
          <Link
            href="/exercises"
            className="border-foreground active:bg-foreground active:text-background border px-3 py-1.5 text-xs font-medium"
          >
            Exercises
          </Link>
          <form action={logout}>
            <button
              type="submit"
              className="active:text-background border-foreground active:bg-foreground border px-3 py-1.5 text-xs font-medium"
            >
              Log out
            </button>
          </form>
        </div>
      </div>

      {error && (
        <p className="border-foreground border px-3 py-2 text-sm">{error}</p>
      )}

      <div className="flex flex-col gap-3">
        {routines && routines.length > 0 ? (
          routines.map((routine, i) => (
            <Link
              key={routine.id}
              href={`/routines/${routine.id}`}
              className="border-foreground flex flex-col justify-center gap-0.5 border px-5 py-4"
            >
              <span className="text-lg font-medium">
                {routineLetter(i)}
                {routine.label ? ` - ${routine.label}` : ""}
              </span>
            </Link>
          ))
        ) : (
          <p className="text-foreground">No routines yet — create one below.</p>
        )}
      </div>

      <form action={createRoutine}>
        <button
          type="submit"
          className="border-foreground active:bg-foreground active:text-background w-full border px-4 py-3 text-center text-sm font-medium"
        >
          + New routine
        </button>
      </form>
    </div>
  );
}

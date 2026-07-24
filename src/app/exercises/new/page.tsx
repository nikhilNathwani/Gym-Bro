import Link from "next/link";
import { createExercise } from "../actions";

export default async function NewExercisePage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; routineId?: string }>;
}) {
  const { error, routineId } = await searchParams;

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-8">
      <div className="border-foreground flex items-center gap-3 border-b pb-4">
        <Link
          href={routineId ? `/routines/${routineId}` : "/exercises"}
          className="text-lg"
        >
          ←
        </Link>
        <h1 className="text-2xl">New exercise</h1>
      </div>

      {error && (
        <p className="border-foreground border px-3 py-2 text-sm">{error}</p>
      )}

      <form action={createExercise} className="flex flex-col gap-4">
        {routineId && (
          <input type="hidden" name="routineId" value={routineId} />
        )}

        <div className="flex flex-col gap-1">
          <label className="text-sm font-medium" htmlFor="name">
            Name
          </label>
          <input
            id="name"
            name="name"
            type="text"
            required
            autoFocus
            className="border-foreground bg-background w-full border px-3 py-2 text-base outline-none"
          />
        </div>

        <button
          type="submit"
          className="text-background bg-foreground border-foreground active:bg-background active:text-foreground w-full border px-4 py-3 text-base font-medium"
        >
          Create exercise
        </button>
      </form>
    </div>
  );
}

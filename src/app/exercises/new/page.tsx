import Link from "next/link";
import { ArrowLeftIcon } from "@/components/icons";
import { createExercise } from "../actions";

export default async function NewExercisePage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-8">
      <div>
        <Link
          href="/exercises"
          className="text-foreground flex items-center gap-1 pb-2 text-sm"
        >
          <ArrowLeftIcon className="h-4 w-4" />
          All exercises
        </Link>
        <h1 className="border-foreground border-b pb-4 text-2xl">
          New exercise
        </h1>
      </div>

      {error && (
        <p className="border-foreground border px-3 py-2 text-sm">{error}</p>
      )}

      <form action={createExercise} className="flex flex-col gap-4">
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

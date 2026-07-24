import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { ExerciseDetail } from "@/lib/types";
import { addCue, deleteCue, deleteLogEntry, updateExercise } from "../actions";
import { DeleteExerciseButton } from "./DeleteExerciseButton";
import { LogEntryForm } from "./LogEntryForm";

export default async function ExercisePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: exercise, error: exerciseError } = await supabase
    .from("exercises")
    .select(
      "id, name, subtitle, cues(id, text, sort_order, level, is_header), exercise_logs(id, notes, created_at, set_logs(id, set_number, weight, reps))",
    )
    .eq("id", id)
    .order("sort_order", { referencedTable: "cues" })
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

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-8">
      <div className="border-foreground flex items-center justify-between border-b pb-4">
        <div className="flex items-center gap-3">
          <Link href="/exercises" className="text-lg">
            ←
          </Link>
          <h1 className="text-2xl">Edit exercise</h1>
        </div>
        <DeleteExerciseButton exerciseId={exercise.id} />
      </div>

      <form action={updateExercise} className="flex flex-col gap-4">
        <input type="hidden" name="id" value={exercise.id} />

        <div className="flex flex-col gap-1">
          <label className="text-sm font-medium" htmlFor="name">
            Name
          </label>
          <input
            id="name"
            name="name"
            type="text"
            defaultValue={exercise.name}
            required
            className="border-foreground bg-background w-full border px-3 py-2 text-lg font-medium outline-none"
          />
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-sm font-medium" htmlFor="subtitle">
            Subtitle
          </label>
          <input
            id="subtitle"
            name="subtitle"
            type="text"
            defaultValue={exercise.subtitle ?? ""}
            placeholder="e.g. 3 sets × 6–10 reps"
            className="border-foreground bg-background placeholder:text-foreground w-full border px-3 py-2 text-sm outline-none placeholder:opacity-40"
          />
        </div>

        <button
          type="submit"
          className="border-foreground active:bg-foreground active:text-background border px-4 py-2 text-sm font-medium"
        >
          Save changes
        </button>
      </form>

      <div className="flex flex-col gap-3">
        <span className="text-sm font-medium">Cues</span>
        {exercise.cues.length > 0 && (
          <ul className="border-foreground flex flex-col border">
            {exercise.cues.map((cue, i) => (
              <li
                key={cue.id}
                className={`flex items-center justify-between gap-2 px-3 py-2 text-sm ${
                  i > 0 ? "border-foreground border-t" : ""
                }`}
              >
                <span className={cue.level > 0 ? "ml-5" : ""}>
                  {cue.is_header ? (
                    <span className="font-medium">{cue.text}</span>
                  ) : (
                    <>
                      {cue.level > 0 ? "– " : "• "}
                      {cue.text}
                    </>
                  )}
                </span>
                <form action={deleteCue}>
                  <input type="hidden" name="cueId" value={cue.id} />
                  <input type="hidden" name="exerciseId" value={exercise.id} />
                  <button
                    type="submit"
                    className="text-foreground text-xs underline"
                  >
                    Remove
                  </button>
                </form>
              </li>
            ))}
          </ul>
        )}
        <form action={addCue} className="flex gap-2">
          <input type="hidden" name="exerciseId" value={exercise.id} />
          <input
            name="text"
            type="text"
            placeholder="Add a cue…"
            className="border-foreground bg-background w-full border px-3 py-2 text-base outline-none"
          />
          <button
            type="submit"
            className="border-foreground active:bg-foreground active:text-background border px-3 py-2 text-sm font-medium"
          >
            Add
          </button>
        </form>
      </div>

      <div className="flex flex-col gap-3">
        <span className="text-sm font-medium">History</span>
        {exercise.exercise_logs.length > 0 ? (
          <div className="flex flex-col gap-3">
            {exercise.exercise_logs.map((log) => (
              <div key={log.id} className="border-foreground border p-3">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium">
                    {new Date(log.created_at).toLocaleDateString(undefined, {
                      month: "short",
                      day: "numeric",
                      year: "numeric",
                    })}
                  </span>
                  <form action={deleteLogEntry}>
                    <input type="hidden" name="exerciseLogId" value={log.id} />
                    <input
                      type="hidden"
                      name="exerciseId"
                      value={exercise.id}
                    />
                    <button
                      type="submit"
                      className="text-foreground text-xs underline"
                    >
                      Delete
                    </button>
                  </form>
                </div>
                {log.set_logs.length > 0 && (
                  <table className="mt-2 w-full text-sm">
                    <thead>
                      <tr className="text-foreground text-left">
                        <th className="font-normal">Set</th>
                        <th className="font-normal">Weight</th>
                        <th className="font-normal">Reps</th>
                      </tr>
                    </thead>
                    <tbody>
                      {log.set_logs.map((set) => (
                        <tr key={set.id}>
                          <td>{set.set_number}</td>
                          <td>{set.weight ?? "—"}</td>
                          <td>{set.reps ?? "—"}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
                {log.notes && (
                  <p className="text-foreground mt-2 text-sm">{log.notes}</p>
                )}
              </div>
            ))}
          </div>
        ) : (
          <p className="text-foreground">No logged sessions yet.</p>
        )}
      </div>

      <LogEntryForm exerciseId={exercise.id} />
    </div>
  );
}

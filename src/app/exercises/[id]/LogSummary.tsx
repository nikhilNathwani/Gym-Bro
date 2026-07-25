import type { ExerciseLog } from "@/lib/types";

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString(undefined, {
    month: "numeric",
    day: "numeric",
    year: "2-digit",
  });
}

export function LogSummary({ log }: { log: ExerciseLog }) {
  return (
    <div className="flex flex-col gap-1 text-sm">
      {log.notes && (
        <div className="flex gap-2">
          <span className="text-foreground w-14 shrink-0">
            {formatDate(log.created_at)}
          </span>
          <span className="min-w-0 flex-1 truncate">{log.notes}</span>
        </div>
      )}
      {log.set_logs.length > 0 && (
        <>
          <div className="flex gap-2">
            <span className="text-foreground w-14 shrink-0">Reps</span>
            <span>{log.set_logs.map((s) => s.reps ?? "—").join(", ")}</span>
          </div>
          <div className="flex gap-2">
            <span className="text-foreground w-14 shrink-0">Weight</span>
            <span>{log.set_logs.map((s) => s.weight ?? "—").join(", ")}</span>
          </div>
        </>
      )}
    </div>
  );
}

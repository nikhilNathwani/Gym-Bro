import Link from "next/link";
import { ArrowLeftIcon } from "@/components/icons";
import { DeleteExerciseButton } from "./DeleteExerciseButton";
import { EditableExerciseName } from "./EditableExerciseName";

export function StickyExerciseHeader({
  exerciseId,
  initialName,
  isEditing,
  onToggleEditing,
  backHref,
  backLabel,
}: {
  exerciseId: string;
  initialName: string;
  isEditing: boolean;
  onToggleEditing: () => void;
  backHref: string;
  backLabel: string;
}) {
  return (
    <div className="bg-background sticky top-0 z-10">
      <Link
        href={backHref}
        className="text-foreground flex items-center gap-1 pb-2 text-sm"
      >
        <ArrowLeftIcon className="h-4 w-4" />
        {backLabel}
      </Link>
      <div className="border-foreground border-b pb-4">
        <EditableExerciseName
          exerciseId={exerciseId}
          initialName={initialName}
        />
        <div className="mt-1 flex items-center gap-3">
          <button
            type="button"
            onClick={onToggleEditing}
            className="text-foreground text-xs underline"
          >
            {isEditing ? "Done" : "Edit"}
          </button>
          <DeleteExerciseButton exerciseId={exerciseId} />
        </div>
      </div>
    </div>
  );
}

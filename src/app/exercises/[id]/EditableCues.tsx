"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import { updateCues } from "../actions";

export function EditableCues({
  exerciseId,
  initialCues,
  canEdit,
}: {
  exerciseId: string;
  initialCues: string;
  canEdit: boolean;
}) {
  const [cues, setCues] = useState(initialCues);
  const [isEditing, setIsEditing] = useState(false);
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [, startTransition] = useTransition();
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const showTextarea = canEdit && isEditing;

  function save(next: string) {
    const formData = new FormData();
    formData.set("exerciseId", exerciseId);
    formData.set("cues", next);
    startTransition(() => {
      updateCues(formData);
    });
  }

  function resize() {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${el.scrollHeight}px`;
  }

  useEffect(() => {
    if (!showTextarea) return;
    resize();
    const el = textareaRef.current;
    el?.focus();
    el?.setSelectionRange(el.value.length, el.value.length);
  }, [showTextarea]);

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium">Cues</span>
        <div className="flex gap-3">
          {canEdit && !isCollapsed && (
            <button
              type="button"
              onClick={() => setIsEditing((v) => !v)}
              className="text-foreground text-xs underline"
            >
              {isEditing ? "Done" : "Edit"}
            </button>
          )}
          <button
            type="button"
            onClick={() => setIsCollapsed((v) => !v)}
            className="text-foreground text-xs underline"
          >
            {isCollapsed ? "Show" : "Hide"}
          </button>
        </div>
      </div>

      {!isCollapsed &&
        (showTextarea ? (
          <textarea
            ref={textareaRef}
            value={cues}
            onChange={(e) => {
              setCues(e.target.value);
              resize();
            }}
            onBlur={() => save(cues)}
            placeholder="Cues — anything worth remembering for this exercise. One per line; use your own hyphens/indentation for structure."
            className="border-foreground bg-background max-h-[9.875rem] w-full resize-none overflow-y-auto border px-3 py-2 text-sm outline-none"
          />
        ) : cues ? (
          <p className="border-foreground max-h-[9.875rem] overflow-y-auto border px-3 py-2 text-sm whitespace-pre-wrap">
            {cues}
          </p>
        ) : (
          <p className="border-foreground text-foreground border px-3 py-2 text-sm opacity-40">
            {canEdit ? "No cues yet — tap Edit to add some." : "No cues yet."}
          </p>
        ))}
    </div>
  );
}

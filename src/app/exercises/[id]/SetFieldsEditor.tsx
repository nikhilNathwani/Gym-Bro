"use client";

import { useEffect, useRef, useState } from "react";
import {
  NumericKeypad,
  type KeypadSuggestion,
} from "@/components/NumericKeypad";
import type { SetLog } from "@/lib/types";

const WEIGHT_STEP = 5;
const REP_STEP = 1;

type Field = "weight" | "reps";

function lastSegment(value: string) {
  const segments = value.split(",");
  return segments[segments.length - 1];
}

function priorSegment(value: string) {
  const segments = value.split(",");
  return segments.length > 1 ? segments[segments.length - 2] : "";
}

function replaceLastSegment(value: string, replacement: string) {
  const segments = value.split(",");
  segments[segments.length - 1] = replacement;
  return segments.join(",");
}

// Renders the Weight/Reps comma-list fields plus the custom on-screen
// keypad that backs them. Meant to sit inside a <form> — the two inputs
// are named "weight"/"reps" so plain FormData submission picks them up
// regardless of which server action the surrounding form points at.
export function SetFieldsEditor({
  initialWeight = "",
  initialReps = "",
  previousSets = [],
}: {
  initialWeight?: string;
  initialReps?: string;
  previousSets?: SetLog[];
}) {
  const [weightText, setWeightText] = useState(initialWeight);
  const [repsText, setRepsText] = useState(initialReps);
  const [active, setActive] = useState<Field | null>(null);
  const [keypadHeight, setKeypadHeight] = useState(0);
  const keypadRef = useRef<HTMLDivElement>(null);
  const weightInputRef = useRef<HTMLInputElement>(null);
  const repsInputRef = useRef<HTMLInputElement>(null);

  const fieldText = { weight: weightText, reps: repsText };
  const setters = { weight: setWeightText, reps: setRepsText };

  function appendDigit(field: Field, digit: string) {
    setters[field]((prev) => prev + digit);
  }

  function applyDecimal(field: Field) {
    setters[field]((prev) => {
      const current = lastSegment(prev);
      if (current.includes(".")) return prev;
      return replaceLastSegment(prev, current ? current + "." : "0.");
    });
  }

  function applyComma(field: Field) {
    setters[field]((prev) => {
      if (prev === "" || prev.endsWith(",")) return prev;
      return prev + ",";
    });
  }

  function applyBackspace(field: Field) {
    setters[field]((prev) => prev.slice(0, -1));
  }

  function applySuggestion(field: Field, value: string) {
    setters[field]((prev) => replaceLastSegment(prev, value) + ",");
  }

  function trimTrailingComma(field: Field) {
    setters[field]((prev) => (prev.endsWith(",") ? prev.slice(0, -1) : prev));
  }

  // Leaving a field (Done, tap outside, or focusing the other field) should
  // never leave a dangling trailing comma behind.
  useEffect(() => {
    return () => {
      if (active) trimTrailingComma(active);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active]);

  // Keep the keypad's own height in sync so the surrounding form can
  // reserve exactly that much scroll room — otherwise anything below the
  // fixed keypad (like a Save button) is unreachable while it's open.
  useEffect(() => {
    if (!active || !keypadRef.current) {
      setKeypadHeight(0);
      return;
    }
    const el = keypadRef.current;
    const observer = new ResizeObserver(([entry]) =>
      setKeypadHeight(entry.contentRect.height),
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [active]);

  // Physical keyboard support: digits, ".", ",", and backspace/delete drive
  // the same handlers as the on-screen keys.
  useEffect(() => {
    if (!active) return;
    function handleKeyDown(e: KeyboardEvent) {
      if (!active || e.metaKey || e.ctrlKey || e.altKey) return;
      if (e.key >= "0" && e.key <= "9") {
        e.preventDefault();
        appendDigit(active, e.key);
      } else if (e.key === ".") {
        e.preventDefault();
        applyDecimal(active);
      } else if (e.key === ",") {
        e.preventDefault();
        applyComma(active);
      } else if (e.key === "Backspace" || e.key === "Delete") {
        e.preventDefault();
        applyBackspace(active);
      }
    }
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active]);

  // Tapping anywhere outside the keypad and outside both fields dismisses
  // it. Deliberately not a blocking overlay — that would also swallow taps
  // on the other field, breaking direct switching between them.
  useEffect(() => {
    if (!active) return;
    function handlePointerDown(e: PointerEvent) {
      const target = e.target as Node;
      if (keypadRef.current?.contains(target)) return;
      if (weightInputRef.current?.contains(target)) return;
      if (repsInputRef.current?.contains(target)) return;
      setActive(null);
    }
    document.addEventListener("pointerdown", handlePointerDown);
    return () => document.removeEventListener("pointerdown", handlePointerDown);
  }, [active]);

  function previousLine(field: Field) {
    if (previousSets.length === 0) return "";
    return previousSets.map((s) => s[field] ?? "").join(",");
  }

  function getSuggestions(field: Field): KeypadSuggestion[] {
    const value = fieldText[field];
    const segmentIndex = value.split(",").length - 1;
    const chips: KeypadSuggestion[] = [];

    const lastTime = previousSets.find(
      (s) => s.set_number === segmentIndex + 1,
    )?.[field];
    if (lastTime != null) {
      chips.push({ label: `${lastTime} last time`, value: String(lastTime) });
    }

    const prior = priorSegment(value);
    if (prior) {
      chips.push({ label: "same", value: prior });
      const n = parseFloat(prior);
      if (!Number.isNaN(n)) {
        const step = field === "reps" ? REP_STEP : WEIGHT_STEP;
        chips.push({ label: `+${step}`, value: String(n + step) });
        chips.push({ label: `-${step}`, value: String(Math.max(0, n - step)) });
      }
    }

    if (chips.length === 0) {
      const fallback =
        field === "reps" ? ["8", "10", "12", "15"] : ["10", "25", "45"];
      fallback.forEach((v) => chips.push({ label: v, value: v }));
    }

    return chips.slice(0, 4);
  }

  const activeValue = active ? fieldText[active] : "";
  const activeSuggestions = active ? getSuggestions(active) : [];

  return (
    <div
      className="flex flex-col gap-2"
      style={{ paddingBottom: keypadHeight ? keypadHeight + 16 : undefined }}
    >
      <div className="flex items-center gap-2">
        <span className="text-foreground w-14 shrink-0 text-sm">Weight</span>
        <input
          ref={weightInputRef}
          name="weight"
          type="text"
          inputMode="none"
          readOnly
          value={weightText}
          onFocus={() => setActive("weight")}
          placeholder={previousLine("weight") || "e.g. 25,25,27.5"}
          className={`border-foreground bg-background w-full border px-3 py-2 text-base outline-none ${
            active === "weight" ? "ring-foreground ring-1" : ""
          }`}
        />
      </div>
      <div className="flex items-center gap-2">
        <span className="text-foreground w-14 shrink-0 text-sm">Reps</span>
        <input
          ref={repsInputRef}
          name="reps"
          type="text"
          inputMode="none"
          readOnly
          value={repsText}
          onFocus={() => setActive("reps")}
          placeholder={previousLine("reps") || "e.g. 10,10,8"}
          className={`border-foreground bg-background w-full border px-3 py-2 text-base outline-none ${
            active === "reps" ? "ring-foreground ring-1" : ""
          }`}
        />
      </div>

      {active && (
        <NumericKeypad
          ref={keypadRef}
          value={activeValue}
          suggestions={activeSuggestions}
          onDigit={(d) => appendDigit(active, d)}
          onDecimal={() => applyDecimal(active)}
          onComma={() => applyComma(active)}
          onBackspace={() => applyBackspace(active)}
          onSuggestion={(v) => applySuggestion(active, v)}
          onDone={() => setActive(null)}
        />
      )}
    </div>
  );
}

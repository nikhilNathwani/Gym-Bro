"use client";

import { forwardRef } from "react";
import { BackspaceIcon } from "./icons";

export type KeypadSuggestion = { label: string; value: string };

const keyClass =
  "border-foreground active:bg-foreground active:text-background flex items-center justify-center border py-3 text-xl font-medium";

export const NumericKeypad = forwardRef<
  HTMLDivElement,
  {
    value: string;
    suggestions: KeypadSuggestion[];
    onDigit: (digit: string) => void;
    onDecimal: () => void;
    onComma: () => void;
    onBackspace: () => void;
    onSuggestion: (value: string) => void;
    onDone: () => void;
  }
>(function NumericKeypad(
  {
    value,
    suggestions,
    onDigit,
    onDecimal,
    onComma,
    onBackspace,
    onSuggestion,
    onDone,
  },
  ref,
) {
  return (
    <div
      ref={ref}
      className="fixed inset-x-0 bottom-0 z-50 flex justify-center"
    >
      <div className="border-foreground bg-background w-full max-w-md border-t">
        <div className="border-foreground flex items-center justify-between border-b px-4 py-2">
          <span className="text-lg font-medium tabular-nums">
            {value || " "}
          </span>
          <button
            type="button"
            onClick={onDone}
            className="text-background bg-foreground px-3 py-1 text-sm font-medium"
          >
            Done
          </button>
        </div>

        {suggestions.length > 0 && (
          <div className="flex gap-2 overflow-x-auto px-3 py-2">
            {suggestions.map((s) => (
              <button
                key={s.label}
                type="button"
                onClick={() => onSuggestion(s.value)}
                className="border-foreground active:bg-foreground active:text-background shrink-0 border px-3 py-1 text-sm font-medium whitespace-nowrap"
              >
                {s.label}
              </button>
            ))}
          </div>
        )}

        <div className="grid grid-cols-4 gap-1 px-3 pb-3">
          <button
            type="button"
            onClick={() => onDigit("1")}
            className={keyClass}
          >
            1
          </button>
          <button
            type="button"
            onClick={() => onDigit("2")}
            className={keyClass}
          >
            2
          </button>
          <button
            type="button"
            onClick={() => onDigit("3")}
            className={keyClass}
          >
            3
          </button>
          <button type="button" onClick={onBackspace} className={keyClass}>
            <BackspaceIcon className="h-6 w-6" />
          </button>

          <button
            type="button"
            onClick={() => onDigit("4")}
            className={keyClass}
          >
            4
          </button>
          <button
            type="button"
            onClick={() => onDigit("5")}
            className={keyClass}
          >
            5
          </button>
          <button
            type="button"
            onClick={() => onDigit("6")}
            className={keyClass}
          >
            6
          </button>
          <button type="button" onClick={onDecimal} className={keyClass}>
            .
          </button>

          <button
            type="button"
            onClick={() => onDigit("7")}
            className={keyClass}
          >
            7
          </button>
          <button
            type="button"
            onClick={() => onDigit("8")}
            className={keyClass}
          >
            8
          </button>
          <button
            type="button"
            onClick={() => onDigit("9")}
            className={keyClass}
          >
            9
          </button>
          <button type="button" onClick={onComma} className={keyClass}>
            ,
          </button>

          <button
            type="button"
            onClick={() => onDigit("0")}
            className={`${keyClass} col-span-4`}
          >
            0
          </button>
        </div>
      </div>
    </div>
  );
});

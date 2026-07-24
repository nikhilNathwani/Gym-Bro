/** "Routine A", "Routine B", ... from a zero-based position in a sort_order-ordered list. */
export function routineLetter(index: number): string {
  return `Routine ${String.fromCharCode(65 + index)}`;
}

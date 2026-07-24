"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export async function updateRoutineLabel(formData: FormData) {
  const id = formData.get("id") as string;
  const label = (formData.get("label") as string)?.trim() || null;
  const supabase = await createClient();

  await supabase.from("routines").update({ label }).eq("id", id);
  revalidatePath(`/routines/${id}`);
}

export async function deleteRoutine(formData: FormData) {
  const id = formData.get("id") as string;
  const supabase = await createClient();

  await supabase.from("routines").delete().eq("id", id);
  redirect("/");
}

export async function addExerciseToRoutine(formData: FormData) {
  const routineId = formData.get("routineId") as string;
  const exerciseId = formData.get("exerciseId") as string;
  const supabase = await createClient();

  const { count } = await supabase
    .from("routine_exercises")
    .select("id", { count: "exact", head: true })
    .eq("routine_id", routineId);

  await supabase.from("routine_exercises").insert({
    routine_id: routineId,
    exercise_id: exerciseId,
    sort_order: count ?? 0,
  });

  revalidatePath(`/routines/${routineId}`);
}

export async function removeExerciseFromRoutine(formData: FormData) {
  const routineExerciseId = formData.get("routineExerciseId") as string;
  const routineId = formData.get("routineId") as string;
  const supabase = await createClient();

  await supabase.from("routine_exercises").delete().eq("id", routineExerciseId);
  revalidatePath(`/routines/${routineId}`);
}

export async function moveExerciseInRoutine(formData: FormData) {
  const routineExerciseId = formData.get("routineExerciseId") as string;
  const routineId = formData.get("routineId") as string;
  const direction = formData.get("direction") as "up" | "down";
  const supabase = await createClient();

  const { data: rows } = await supabase
    .from("routine_exercises")
    .select("id, sort_order")
    .eq("routine_id", routineId)
    .order("sort_order")
    .returns<{ id: string; sort_order: number }[]>();

  if (!rows) return;

  const index = rows.findIndex((r) => r.id === routineExerciseId);
  const swapIndex = direction === "up" ? index - 1 : index + 1;
  if (index === -1 || swapIndex < 0 || swapIndex >= rows.length) return;

  const current = rows[index];
  const neighbor = rows[swapIndex];

  await supabase
    .from("routine_exercises")
    .update({ sort_order: neighbor.sort_order })
    .eq("id", current.id);
  await supabase
    .from("routine_exercises")
    .update({ sort_order: current.sort_order })
    .eq("id", neighbor.id);

  revalidatePath(`/routines/${routineId}`);
}

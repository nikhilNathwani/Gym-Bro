"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export async function createExercise(formData: FormData) {
  const name = (formData.get("name") as string)?.trim();
  const routineId = (formData.get("routineId") as string) || null;

  if (!name) {
    redirect(
      `/exercises/new?error=${encodeURIComponent("Name is required")}${routineId ? `&routineId=${routineId}` : ""}`,
    );
  }

  const supabase = await createClient();

  const { data: exercise, error } = await supabase
    .from("exercises")
    .insert({ name })
    .select("id")
    .single();

  if (error || !exercise) {
    redirect(
      `/exercises/new?error=${encodeURIComponent(error?.message ?? "Could not create exercise")}`,
    );
  }

  if (routineId) {
    const { count } = await supabase
      .from("routine_exercises")
      .select("id", { count: "exact", head: true })
      .eq("routine_id", routineId);

    await supabase.from("routine_exercises").insert({
      routine_id: routineId,
      exercise_id: exercise.id,
      sort_order: count ?? 0,
    });

    redirect(`/routines/${routineId}`);
  }

  redirect(`/exercises/${exercise.id}`);
}

export async function updateExercise(formData: FormData) {
  const id = formData.get("id") as string;
  const name = (formData.get("name") as string)?.trim();
  const subtitle = (formData.get("subtitle") as string)?.trim() || null;
  const supabase = await createClient();

  await supabase.from("exercises").update({ name, subtitle }).eq("id", id);

  revalidatePath(`/exercises/${id}`);
}

export async function deleteExercise(formData: FormData) {
  const id = formData.get("id") as string;
  const supabase = await createClient();

  await supabase.from("exercises").delete().eq("id", id);
  redirect("/exercises");
}

export async function addCue(formData: FormData) {
  const exerciseId = formData.get("exerciseId") as string;
  const text = (formData.get("text") as string)?.trim();
  if (!text) return;

  const supabase = await createClient();
  const { count } = await supabase
    .from("cues")
    .select("id", { count: "exact", head: true })
    .eq("exercise_id", exerciseId);

  await supabase
    .from("cues")
    .insert({ exercise_id: exerciseId, text, sort_order: count ?? 0 });

  revalidatePath(`/exercises/${exerciseId}`);
}

export async function deleteCue(formData: FormData) {
  const cueId = formData.get("cueId") as string;
  const exerciseId = formData.get("exerciseId") as string;
  const supabase = await createClient();

  await supabase.from("cues").delete().eq("id", cueId);
  revalidatePath(`/exercises/${exerciseId}`);
}

export async function addLogEntry(formData: FormData) {
  const exerciseId = formData.get("exerciseId") as string;
  const notes = (formData.get("notes") as string)?.trim() || null;
  const weights = formData.getAll("weight");
  const reps = formData.getAll("reps");

  const supabase = await createClient();

  const { data: session, error: sessionError } = await supabase
    .from("workout_sessions")
    .insert({})
    .select("id")
    .single();

  if (sessionError || !session) return;

  const { data: exerciseLog, error: logError } = await supabase
    .from("exercise_logs")
    .insert({ session_id: session.id, exercise_id: exerciseId, notes })
    .select("id")
    .single();

  if (logError || !exerciseLog) return;

  const setRows = weights
    .map((weight, i) => ({
      exercise_log_id: exerciseLog.id,
      set_number: i + 1,
      weight: parseFloatOrNull(weight),
      reps: parseIntOrNull(reps[i]),
    }))
    .filter((row) => row.weight !== null || row.reps !== null);

  if (setRows.length > 0) {
    await supabase.from("set_logs").insert(setRows);
  }

  revalidatePath(`/exercises/${exerciseId}`);
}

export async function deleteLogEntry(formData: FormData) {
  const exerciseLogId = formData.get("exerciseLogId") as string;
  const exerciseId = formData.get("exerciseId") as string;
  const supabase = await createClient();

  await supabase.from("exercise_logs").delete().eq("id", exerciseLogId);
  revalidatePath(`/exercises/${exerciseId}`);
}

function parseIntOrNull(value: FormDataEntryValue | null): number | null {
  if (typeof value !== "string" || value.trim() === "") return null;
  const n = parseInt(value, 10);
  return Number.isNaN(n) ? null : n;
}

function parseFloatOrNull(value: FormDataEntryValue | null): number | null {
  if (typeof value !== "string" || value.trim() === "") return null;
  const n = parseFloat(value);
  return Number.isNaN(n) ? null : n;
}

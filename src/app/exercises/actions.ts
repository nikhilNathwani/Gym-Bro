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

// Partial update: the name field and subtitle field are edited by separate
// inline inputs that each save independently on blur, so only whichever
// field is present in formData gets touched — otherwise saving one would
// clobber the other with an empty value.
export async function updateExercise(formData: FormData) {
  const id = formData.get("id") as string;
  const supabase = await createClient();
  const updates: Record<string, string | null> = {};

  if (formData.has("name")) {
    const name = (formData.get("name") as string)?.trim();
    if (name) updates.name = name;
  }
  if (formData.has("subtitle")) {
    updates.subtitle = (formData.get("subtitle") as string)?.trim() || null;
  }

  if (Object.keys(updates).length > 0) {
    await supabase.from("exercises").update(updates).eq("id", id);
  }

  revalidatePath(`/exercises/${id}`);
}

export async function deleteExercise(formData: FormData) {
  const id = formData.get("id") as string;
  const supabase = await createClient();

  await supabase.from("exercises").delete().eq("id", id);
  redirect("/exercises");
}

export async function updateCues(formData: FormData) {
  const exerciseId = formData.get("exerciseId") as string;
  const cues = (formData.get("cues") as string) ?? "";
  const supabase = await createClient();

  await supabase
    .from("exercises")
    .update({ cues: cues.trim() === "" ? null : cues })
    .eq("id", exerciseId);

  revalidatePath(`/exercises/${exerciseId}`);
}

export async function addLogEntry(formData: FormData) {
  const exerciseId = formData.get("exerciseId") as string;
  const notes = (formData.get("notes") as string)?.trim() || null;
  const weights = splitCommaList(formData.get("weight"));
  const reps = splitCommaList(formData.get("reps"));

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

  const setCount = Math.max(weights.length, reps.length);
  const setRows = Array.from({ length: setCount }, (_, i) => ({
    exercise_log_id: exerciseLog.id,
    set_number: i + 1,
    weight: parseFloatOrNull(weights[i]),
    reps: parseIntOrNull(reps[i]),
  })).filter((row) => row.weight !== null || row.reps !== null);

  if (setRows.length > 0) {
    await supabase.from("set_logs").insert(setRows);
  }

  revalidatePath(`/exercises/${exerciseId}`);
}

export async function updateLogEntry(formData: FormData) {
  const exerciseLogId = formData.get("exerciseLogId") as string;
  const exerciseId = formData.get("exerciseId") as string;
  const notes = (formData.get("notes") as string)?.trim() || null;
  const weights = splitCommaList(formData.get("weight"));
  const reps = splitCommaList(formData.get("reps"));

  const supabase = await createClient();

  // Deliberately does not touch created_at — editing a note days later
  // should still leave the entry attributed to the day it was logged.
  await supabase
    .from("exercise_logs")
    .update({ notes })
    .eq("id", exerciseLogId);

  await supabase.from("set_logs").delete().eq("exercise_log_id", exerciseLogId);

  const setCount = Math.max(weights.length, reps.length);
  const setRows = Array.from({ length: setCount }, (_, i) => ({
    exercise_log_id: exerciseLogId,
    set_number: i + 1,
    weight: parseFloatOrNull(weights[i]),
    reps: parseIntOrNull(reps[i]),
  })).filter((row) => row.weight !== null || row.reps !== null);

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

function splitCommaList(value: FormDataEntryValue | null): string[] {
  if (typeof value !== "string") return [];
  return value
    .split(",")
    .map((v) => v.trim())
    .filter((v) => v !== "");
}

function parseIntOrNull(value: string | undefined): number | null {
  if (value === undefined) return null;
  const n = parseInt(value, 10);
  return Number.isNaN(n) ? null : n;
}

function parseFloatOrNull(value: string | undefined): number | null {
  if (value === undefined) return null;
  const n = parseFloat(value);
  return Number.isNaN(n) ? null : n;
}

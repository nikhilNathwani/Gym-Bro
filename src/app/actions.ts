"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export async function logout() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}

export async function createRoutine(formData: FormData) {
  const label = (formData.get("label") as string)?.trim() || null;
  const supabase = await createClient();

  const { count } = await supabase
    .from("routines")
    .select("id", { count: "exact", head: true });

  const { data, error } = await supabase
    .from("routines")
    .insert({ label, sort_order: count ?? 0 })
    .select("id")
    .single();

  if (error || !data) {
    redirect(
      `/?error=${encodeURIComponent(error?.message ?? "Could not create routine")}`,
    );
  }

  redirect(`/routines/${data.id}`);
}

export async function moveRoutine(formData: FormData) {
  const id = formData.get("id") as string;
  const direction = formData.get("direction") as "up" | "down";
  const supabase = await createClient();

  const { data: routines } = await supabase
    .from("routines")
    .select("id, sort_order")
    .order("sort_order")
    .returns<{ id: string; sort_order: number }[]>();

  if (!routines) return;

  const index = routines.findIndex((r) => r.id === id);
  const swapIndex = direction === "up" ? index - 1 : index + 1;
  if (index === -1 || swapIndex < 0 || swapIndex >= routines.length) return;

  const current = routines[index];
  const neighbor = routines[swapIndex];

  await supabase
    .from("routines")
    .update({ sort_order: neighbor.sort_order })
    .eq("id", current.id);
  await supabase
    .from("routines")
    .update({ sort_order: current.sort_order })
    .eq("id", neighbor.id);

  revalidatePath("/");
}

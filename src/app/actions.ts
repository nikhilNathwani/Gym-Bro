"use server";

import { redirect } from "next/navigation";
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

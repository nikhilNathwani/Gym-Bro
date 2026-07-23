import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { logout } from "./actions";
import type { Day } from "@/lib/types";

export default async function Home() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: days } = await supabase
    .from("days")
    .select("id, name, sort_order")
    .order("sort_order")
    .returns<Day[]>();

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 bg-neutral-950 px-4 py-8 text-neutral-100">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Gym Bro</h1>
        <form action={logout}>
          <button
            type="submit"
            className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-400 active:bg-neutral-800"
          >
            Log out
          </button>
        </form>
      </div>
      <p className="-mt-4 text-sm text-neutral-500">{user?.email}</p>

      <div className="flex flex-col gap-3">
        {days && days.length > 0 ? (
          days.map((day) => (
            <Link
              key={day.id}
              href={`/days/${day.id}`}
              className="rounded-2xl bg-neutral-900 px-5 py-4 text-lg font-medium shadow active:bg-neutral-800"
            >
              {day.name}
            </Link>
          ))
        ) : (
          <p className="text-neutral-500">
            No days yet. Add one in Supabase to get started.
          </p>
        )}
      </div>
    </div>
  );
}

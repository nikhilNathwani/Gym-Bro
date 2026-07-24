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
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-8">
      <div className="flex items-center justify-between border-b-2 border-black pb-4">
        <h1 className="text-2xl font-semibold">Gym Bro</h1>
        <form action={logout}>
          <button
            type="submit"
            className="border-2 border-black px-3 py-1.5 text-xs font-medium active:bg-black active:text-background"
          >
            Log out
          </button>
        </form>
      </div>
      <p className="-mt-4 text-sm text-black">
        {user?.email ?? "auth bypassed — dev mode"}
      </p>

      <div className="flex flex-col gap-3">
        {days && days.length > 0 ? (
          days.map((day) => (
            <Link
              key={day.id}
              href={`/days/${day.id}`}
              className="border-2 border-black px-5 py-4 text-lg font-medium active:bg-black active:text-background"
            >
              {day.name}
            </Link>
          ))
        ) : (
          <p className="text-black">
            No days yet. Add one in Supabase to get started.
          </p>
        )}
      </div>
    </div>
  );
}

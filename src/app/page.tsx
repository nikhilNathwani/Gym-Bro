import { createClient } from "@/lib/supabase/server";
import { logout } from "./actions";

export default async function Home() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-6 bg-neutral-950 px-4 text-neutral-100">
      <h1 className="text-2xl font-semibold">Gym Bro</h1>
      <p className="text-neutral-400">Logged in as {user?.email}</p>
      <p className="text-sm text-neutral-500">
        Day list and workout logging land in the next build phase.
      </p>
      <form action={logout}>
        <button
          type="submit"
          className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-300 active:bg-neutral-800"
        >
          Log out
        </button>
      </form>
    </div>
  );
}

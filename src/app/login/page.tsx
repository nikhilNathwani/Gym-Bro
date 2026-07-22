import { login } from "./actions";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;

  return (
    <div className="flex min-h-screen items-center justify-center bg-neutral-950 px-4">
      <form
        action={login}
        className="w-full max-w-sm rounded-2xl bg-neutral-900 p-6 shadow-xl"
      >
        <h1 className="mb-6 text-xl font-semibold text-neutral-100">
          Gym Bro
        </h1>

        {error && (
          <p className="mb-4 rounded-lg bg-red-950 px-3 py-2 text-sm text-red-300">
            {error}
          </p>
        )}

        <label className="mb-1 block text-sm text-neutral-400" htmlFor="email">
          Email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          required
          autoComplete="email"
          className="mb-4 w-full rounded-lg border border-neutral-700 bg-neutral-800 px-3 py-3 text-base text-neutral-100 outline-none focus:border-neutral-500"
        />

        <label
          className="mb-1 block text-sm text-neutral-400"
          htmlFor="password"
        >
          Password
        </label>
        <input
          id="password"
          name="password"
          type="password"
          required
          autoComplete="current-password"
          className="mb-6 w-full rounded-lg border border-neutral-700 bg-neutral-800 px-3 py-3 text-base text-neutral-100 outline-none focus:border-neutral-500"
        />

        <button
          type="submit"
          className="w-full rounded-lg bg-neutral-100 px-4 py-3 text-base font-medium text-neutral-900 active:bg-neutral-300"
        >
          Log in
        </button>
      </form>
    </div>
  );
}

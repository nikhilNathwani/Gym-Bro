import { login } from "./actions";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;

  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <form
        action={login}
        className="w-full max-w-sm border-2 border-black p-6"
      >
        <h1 className="mb-6 text-xl font-semibold">Gym Bro</h1>

        {error && (
          <p className="mb-4 border-2 border-black px-3 py-2 text-sm">
            {error}
          </p>
        )}

        <label className="mb-1 block text-sm text-black" htmlFor="email">
          Email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          required
          autoComplete="email"
          className="mb-4 w-full border-2 border-black bg-background px-3 py-3 text-base outline-none"
        />

        <label
          className="mb-1 block text-sm text-black"
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
          className="mb-6 w-full border-2 border-black bg-background px-3 py-3 text-base outline-none"
        />

        <button
          type="submit"
          className="w-full border-2 border-black bg-black px-4 py-3 text-base font-medium text-background active:bg-background active:text-black"
        >
          Log in
        </button>
      </form>
    </div>
  );
}

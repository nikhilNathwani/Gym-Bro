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
        className="border-foreground w-full max-w-sm border p-6"
      >
        <h1 className="mb-6 text-xl font-semibold">Gym Bro</h1>

        {error && (
          <p className="border-foreground mb-4 border px-3 py-2 text-sm">
            {error}
          </p>
        )}

        <label className="text-foreground mb-1 block text-sm" htmlFor="email">
          Email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          required
          autoComplete="email"
          className="bg-background border-foreground mb-4 w-full border px-3 py-3 text-base outline-none"
        />

        <label
          className="text-foreground mb-1 block text-sm"
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
          className="bg-background border-foreground mb-6 w-full border px-3 py-3 text-base outline-none"
        />

        <button
          type="submit"
          className="text-background active:bg-background border-foreground bg-foreground active:text-foreground w-full border px-4 py-3 text-base font-medium"
        >
          Log in
        </button>
      </form>
    </div>
  );
}

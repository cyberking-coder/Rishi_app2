"use client";

import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

/**
 * Who you are, and a way out.
 *
 * The storefront originally had a permanent "Sign in" link and nothing
 * else, so signing in changed nothing visible — which reads as the
 * sign-in having failed, and on a page whose whole job is taking money
 * that is the worst possible ambiguity. It also matters here more than
 * on most sites: access is granted to the account that paid, so which
 * account you are signed into is the one fact a buyer must be able to
 * check before paying.
 */
export function AccountNav({ email }: { email: string | null }) {
  const router = useRouter();

  async function signOut() {
    await createClient().auth.signOut();
    // refresh() re-runs the server layout so the header re-reads the
    // session, rather than leaving a stale email until a hard reload.
    router.refresh();
    router.push("/store");
  }

  if (!email) {
    return (
      <Link href="/store/signin" className="hover:text-foreground">
        Sign in
      </Link>
    );
  }

  return (
    <div className="flex items-center gap-4">
      <span className="max-w-[45vw] truncate text-foreground" title={email}>
        {email}
      </span>
      <button
        type="button"
        onClick={signOut}
        className="underline hover:text-foreground"
      >
        Sign out
      </button>
    </div>
  );
}

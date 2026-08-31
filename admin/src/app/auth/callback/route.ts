import { NextRequest, NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { env } from "@/lib/env";

/**
 * Completes a web OAuth sign-in (Google) for storefront buyers.
 *
 * Supabase redirects the browser here with `?code=...` after the person
 * picks their Google account. We exchange that code for a session, set the
 * auth cookies on the redirect response, and forward to `next` — a same-site
 * path only, so this can never be turned into an open redirect.
 *
 * This is what lets an iPhone member who created their account with Google in
 * the app sign in to the store as the SAME Supabase user (same email → same
 * user_id), so a purchase made here grants access that the app then sees.
 * Without it, a Google user has no password and cannot sign in to buy at all.
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const nextParam = searchParams.get("next") ?? "/store";
  const next = nextParam.startsWith("/") ? nextParam : "/store";

  if (!code) {
    return NextResponse.redirect(`${origin}/store/signin?error=oauth`);
  }

  const response = NextResponse.redirect(`${origin}${next}`);
  const supabase = createServerClient(
    env.supabaseUrl(),
    env.supabaseAnonKey(),
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) {
    return NextResponse.redirect(`${origin}/store/signin?error=oauth`);
  }
  return response;
}

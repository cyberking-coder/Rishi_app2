import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

type CookieToSet = { name: string; value: string; options: CookieOptions };

/**
 * Refreshes the Supabase session cookie on every request and bounces
 * unauthenticated visitors to /login. Fine-grained admin-role checks live
 * in `requireAdmin()` on the server, since middleware can't query profiles
 * cheaply on every request.
 */
export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet: CookieToSet[]) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value),
          );
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const isLoginRoute = request.nextUrl.pathname.startsWith("/login");
  // The checkout page and its API route are a public, end-user-facing
  // surface (opened from the mobile app by anonymous browser tabs, not
  // logged-in admin staff) — protected by the signed checkout token
  // instead of a Supabase session. Never gate these behind /login.
  const isPublicCheckoutRoute =
    request.nextUrl.pathname.startsWith("/checkout") ||
    request.nextUrl.pathname.startsWith("/api/checkout");
  // Certificate verification is public by definition — the whole point
  // is that someone who was shown a certificate, and who has no account
  // here at all, can confirm it.
  const isPublicVerifyRoute = request.nextUrl.pathname.startsWith("/verify");
  // The policy pages. Public by obligation, not by preference: Google
  // Play, the App Store and Razorpay all fetch these anonymously to
  // check them, and so does anybody deciding whether to pay.
  //
  // Leaving them behind the session redirect is exactly how the Play
  // submission was rejected for an "invalid privacy policy" — the
  // reviewer opened /privacy and was shown the admin login screen.
  const isPublicPolicyRoute = [
    "/terms",
    "/privacy",
    "/refunds",
    "/contact",
    // Play's User Data policy requires the deletion URL to be reachable
    // anonymously, exactly like the privacy policy. Adding a page under
    // (legal) without adding it here is what caused the rejection.
    "/delete-account",
  ]
    .some((route) => request.nextUrl.pathname.startsWith(route));

  if (
    !user &&
    !isLoginRoute &&
    !isPublicCheckoutRoute &&
    !isPublicVerifyRoute &&
    !isPublicPolicyRoute
  ) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  if (user && isLoginRoute) {
    const url = request.nextUrl.clone();
    url.pathname = "/";
    return NextResponse.redirect(url);
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};

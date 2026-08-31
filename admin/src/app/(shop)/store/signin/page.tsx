"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Eye, EyeOff } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { decodeTarget, mintCheckoutPath } from "@/lib/checkout-link";

/// Buyer sign-in, deliberately not the admin `/login`.
///
/// The two share a Supabase project but not an audience: `/login` leads
/// to the dashboard, which `requireAdmin()` bounces anyone else out of.
/// A customer sent there would sign in successfully and then be told
/// they are not authorised, which reads as a broken purchase.
export default function BuyerSignInPage() {
  return (
    <Suspense fallback={null}>
      <SignInForm />
    </Suspense>
  );
}

function SignInForm() {
  const router = useRouter();
  const params = useSearchParams();
  const target = decodeTarget(params.get("buy"));

  // Landing sends people here with ?mode=signup, so the button they
  // pressed and the form they arrive at agree. Defaulting to sign-in
  // regardless is how somebody who meant to register ends up being told
  // their credentials are invalid.
  const [mode, setMode] = useState<"signin" | "signup">(
    params.get("mode") === "signup" ? "signup" : "signin",
  );
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [confirmSent, setConfirmSent] = useState(false);

  function switchTo(next: "signin" | "signup") {
    setMode(next);
    setError(null);
    setNotice(null);
  }

  /// Supabase's auth errors are written for developers. "Invalid login
  /// credentials" in particular is what somebody sees when they meant to
  /// register and were on the sign-in tab — which was easy to do while
  /// the only way to switch was a text link under the fold.
  function humanise(message: string): string {
    const m = message.toLowerCase();
    if (m.includes("invalid login credentials")) {
      return "That email and password don't match an account. If you haven't bought from us before, choose \"Create account\" above.";
    }
    if (m.includes("email not confirmed")) {
      return "Please confirm your email address first — check your inbox for the link, then sign in.";
    }
    if (m.includes("already registered") || m.includes("already been registered")) {
      return "You already have an account with this email. Choose \"Sign in\" above.";
    }
    if (m.includes("password should be")) {
      return "Please choose a password of at least 6 characters.";
    }
    return message;
  }

  /// Where to land once there is a session: back into the purchase they
  /// started, or the catalogue if they just came to sign in.
  async function continueOn() {
    if (!target) {
      router.push("/store");
      return;
    }
    const path = await mintCheckoutPath(target);
    router.push(path ?? "/store");
  }

  /// Sign in with the same Google account used in the app.
  ///
  /// This is the fix for Google users: they created their account in the app
  /// with Google and have NO password, so email+password sign-in here is
  /// impossible for them. A web OAuth round-trip authenticates the same
  /// Google account — same email, so Supabase resolves it to the SAME user —
  /// and access bought here appears in the app.
  ///
  /// We come back via /auth/callback (which sets the session cookie), then to
  /// `next`: the purchase resumes if one was in flight, otherwise the store.
  async function signInWithGoogle() {
    setBusy(true);
    setError(null);
    setNotice(null);
    const supabase = createClient();

    const buy = params.get("buy");
    const resume =
      target && buy
        ? `/store/signin?buy=${encodeURIComponent(buy)}&resume=1`
        : "/store";
    const redirectTo = `${window.location.origin}/auth/callback?next=${encodeURIComponent(resume)}`;

    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo },
    });
    if (error) {
      setError(humanise(error.message));
      setBusy(false);
    }
    // On success the browser navigates away to Google; nothing else to do.
  }

  // After the Google round-trip we land back here with ?resume=1 and a live
  // session cookie. Continue the purchase (or go to the store) automatically.
  // Also surface a friendly message if the callback reported a failure.
  useEffect(() => {
    if (params.get("error") === "oauth") {
      setError("Google sign-in didn't complete. Please try again.");
      return;
    }
    // Arrived from an email-confirmation link. The email is now verified;
    // they just need to sign in (the confirm link does not carry a session).
    if (params.get("confirmed") === "1") {
      setNotice("Your email is confirmed — sign in below to continue.");
      return;
    }
    if (params.get("resume") !== "1") return;
    let cancelled = false;
    (async () => {
      const supabase = createClient();
      const { data } = await supabase.auth.getUser();
      if (!cancelled && data.user) await continueOn();
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setNotice(null);

    const supabase = createClient();

    try {
      if (mode === "signup") {
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            // Where the confirmation link lands after Supabase verifies the
            // email. Without this it falls back to the project's Site URL —
            // which is why an unconfigured project sends people to
            // localhost. Bringing them back to this page with ?confirmed=1
            // shows a "you're confirmed, sign in" state instead of a dead
            // page, and keeps the purchase on the same tab.
            emailRedirectTo: `${window.location.origin}/store/signin?confirmed=1${
              params.get("buy")
                ? `&buy=${encodeURIComponent(params.get("buy")!)}`
                : ""
            }`,
            // Same metadata key the mobile app sends, so a buyer who signs
            // up here and one who signs up in the app end up with the same
            // shaped profile.
            ...(name.trim() ? { data: { display_name: name.trim() } } : {}),
          },
        });
        if (error) throw error;

        // Supabase does not error when the email already belongs to
        // someone — it returns a user with no identities, to avoid
        // confirming to a stranger which addresses are registered. The
        // mobile app's signup checks the same thing; without it, the
        // person waits for an email that will never arrive.
        if (data.user && (data.user.identities?.length ?? 0) === 0) {
          setError(
            'You already have an account with this email. Choose "Sign in" above.',
          );
          return;
        }

        // No session means the project requires email confirmation. The
        // purchase cannot continue until they are actually signed in, so
        // this gets its own screen rather than a line of text under a
        // form that now looks ready to submit again.
        if (!data.session) {
          setConfirmSent(true);
          return;
        }
      } else {
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        if (error) throw error;
      }

      await continueOn();
    } catch (e) {
      setError(humanise(e instanceof Error ? e.message : String(e)));
    } finally {
      setBusy(false);
    }
  }

  if (confirmSent) {
    return (
      <div className="mx-auto max-w-md">
        <h1 className="text-2xl font-semibold tracking-tight">
          Confirm your email
        </h1>
        <Card className="mt-6">
          <CardContent className="space-y-3 p-5 text-sm text-muted-foreground">
            <p>
              We have sent a confirmation link to{" "}
              <span className="font-medium text-foreground">{email}</span>.
              Open it, then come back and sign in to finish.
            </p>
            <p>
              Nothing has been charged yet — your purchase carries on from
              where you left off once you are signed in.
            </p>
            <Button
              className="w-full"
              onClick={() => {
                setConfirmSent(false);
                switchTo("signin");
              }}
            >
              I have confirmed — sign in
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-md">
      <h1 className="text-2xl font-semibold tracking-tight">
        {mode === "signin" ? "Sign in" : "Create your account"}
      </h1>
      <p className="mt-2 text-sm text-muted-foreground">
        {target
          ? "Sign in the same way you use the app — if you signed in with Google there, choose \"Continue with Google\" here. That keeps it one account, and your access appears in the app."
          : "Sign in the same way you use the app — with Google if that's how you signed in there, otherwise the same email. That keeps everything on one account."}
      </p>

      {/* Both options, equally visible, above the form. As a text link
          under it, "Create an account" was easy to miss — and somebody
          who misses it types their details into the sign-in form and is
          told their credentials are invalid, which reads as the site
          being broken rather than as being on the wrong tab. */}
      <div className="mt-6 grid grid-cols-2 gap-2 rounded-lg border p-1">
        <button
          type="button"
          onClick={() => switchTo("signin")}
          className={`rounded-md px-3 py-2 text-sm font-medium transition-colors ${
            mode === "signin"
              ? "bg-primary text-primary-foreground"
              : "text-muted-foreground hover:text-foreground"
          }`}
        >
          Sign in
        </button>
        <button
          type="button"
          onClick={() => switchTo("signup")}
          className={`rounded-md px-3 py-2 text-sm font-medium transition-colors ${
            mode === "signup"
              ? "bg-primary text-primary-foreground"
              : "text-muted-foreground hover:text-foreground"
          }`}
        >
          Create account
        </button>
      </div>

      <Card className="mt-4">
        <CardContent className="p-5">
          {/* Google first: the people who cannot sign in any other way — the
              ones who used Google in the app and have no password — are
              exactly who this page was failing. */}
          <Button
            type="button"
            variant="outline"
            className="w-full"
            onClick={signInWithGoogle}
            disabled={busy}
          >
            Continue with Google
          </Button>
          <div className="my-4 flex items-center gap-3 text-xs text-muted-foreground">
            <span className="h-px flex-1 bg-border" />
            or with email
            <span className="h-px flex-1 bg-border" />
          </div>

          <form onSubmit={submit} className="space-y-4">
            {mode === "signup" && (
              <div className="space-y-1.5">
                <Label htmlFor="name">Your name</Label>
                <Input
                  id="name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  autoComplete="name"
                />
              </div>
            )}

            <div className="space-y-1.5">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="email"
              />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="password">Password</Label>
              {/* Show/hide, matching the mobile app's auth fields. On a
                  phone keyboard a mistyped password that cannot be read
                  back is the most common reason someone gives up here,
                  and on the create-account side they cannot even fall
                  back on "reset it". */}
              <div className="relative">
                <Input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  required
                  minLength={6}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete={
                    mode === "signup" ? "new-password" : "current-password"
                  }
                  className="pr-10"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="absolute inset-y-0 right-0 flex w-10 items-center justify-center text-muted-foreground hover:text-foreground"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                  aria-pressed={showPassword}
                  // Keeps the field focused when the toggle is tapped,
                  // so the caret does not jump to the end of the value.
                  onMouseDown={(e) => e.preventDefault()}
                  tabIndex={-1}
                >
                  {showPassword ? (
                    <EyeOff className="h-4 w-4" />
                  ) : (
                    <Eye className="h-4 w-4" />
                  )}
                </button>
              </div>
            </div>

            {error && <p className="text-sm text-destructive">{error}</p>}
            {notice && <p className="text-sm text-muted-foreground">{notice}</p>}

            <Button type="submit" className="w-full" disabled={busy}>
              {busy
                ? "One moment…"
                : mode === "signin"
                  ? "Sign in"
                  : "Create account"}
            </Button>
          </form>

        </CardContent>
      </Card>
    </div>
  );
}

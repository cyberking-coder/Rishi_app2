"use client";

import { Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
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

  const [mode, setMode] = useState<"signin" | "signup">("signin");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
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
          // Same metadata key the mobile app sends, so a buyer who signs
          // up here and one who signs up in the app end up with the same
          // shaped profile.
          options: name.trim() ? { data: { display_name: name.trim() } } : undefined,
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
          ? "Use the same email you will sign in with in the app — that is where your access appears."
          : "Use the same email as the app, so everything stays on one account."}
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
              <Input
                id="password"
                type="password"
                required
                minLength={6}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete={
                  mode === "signup" ? "new-password" : "current-password"
                }
              />
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

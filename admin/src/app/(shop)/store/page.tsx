import Link from "next/link";
import { createAdminClient } from "@/lib/supabase/admin";
import { getCurrentProfile } from "@/lib/auth";
import { Card, CardContent } from "@/components/ui/card";
import { BuyButton } from "./buy-button";

export const dynamic = "force-dynamic";

/// The public shopfront.
///
/// Everything here was previously reachable only from inside the mobile
/// app: `mint-checkout-token` answers 401 without a session, so every
/// checkout link was minted for one signed-in user and one item. That
/// was survivable while the app could sell. The iOS build cannot, so
/// this is where iPhone buyers are sent instead.
///
/// Read with the service-role client rather than the anon one because
/// `live_sessions` is `to authenticated` — a signed-out visitor sees
/// nothing through RLS, and a signed-out visitor is the entire audience.
/// Every column is listed explicitly for that reason; in particular
/// `join_url` is never selected, since it is the one field the row-level
/// policy exists to protect.

interface PlanRow {
  id: string;
  name: string;
  description: string | null;
  price: number;
  currency: string;
  billing_interval: string;
}

interface CourseRow {
  id: string;
  title: string;
  description: string | null;
  price_amount: number;
  currency: string;
  cover_image_url: string | null;
}

interface SessionRow {
  id: string;
  title: string;
  description: string | null;
  price_amount: number | null;
  currency: string;
  starts_at: string;
}

function formatPrice(rupees: number, currency: string): string {
  const symbol = currency === "INR" ? "₹" : currency + " ";
  return `${symbol}${rupees % 1 === 0 ? rupees : rupees.toFixed(2)}`;
}

export default async function StorePage() {
  const db = createAdminClient();

  const [plans, courses, sessions] = await Promise.all([
    db
      .from("subscription_plans")
      .select("id, name, description, price, currency, billing_interval")
      .eq("is_active", true)
      .order("price", { ascending: true })
      .returns<PlanRow[]>(),
    // Every published course, not only the priced ones. Filtering on
    // `price_amount > 0` made a course with no price indistinguishable
    // from a broken query — both render as nothing at all — and the
    // admin has no way to tell which. A free course shows without a
    // buy button instead, which says what is actually true about it.
    db
      .from("courses")
      .select("id, title, description, price_amount, currency, cover_image_url")
      .eq("status", "published")
      .order("created_at", { ascending: false })
      .returns<CourseRow[]>(),
    db
      .from("live_sessions")
      .select("id, title, description, price_amount, currency, starts_at")
      .eq("status", "scheduled")
      .gt("price_amount", 0)
      .gt("starts_at", new Date().toISOString())
      .order("starts_at", { ascending: true })
      .returns<SessionRow[]>(),
  ]);

  const planRows = plans.data ?? [];
  const courseRows = courses.data ?? [];
  const sessionRows = sessions.data ?? [];

  // `?? []` on its own is how a failing query becomes an empty page with
  // nothing to explain it — the trap this codebase has already been
  // caught by three times (see the bug chronology: a failing embed
  // returning null data, and n8n failing silently for three deploys).
  // A query that errored says so, and says it where somebody will see it.
  const failures = [
    plans.error && `plans: ${plans.error.message}`,
    courses.error && `courses: ${courses.error.message}`,
    sessions.error && `live sessions: ${sessions.error.message}`,
  ].filter(Boolean) as string[];

  const empty =
    planRows.length === 0 &&
    courseRows.length === 0 &&
    sessionRows.length === 0;

  // Shown only to staff, and only to answer one question that nothing
  // else on the page can: is a missing buy button a broken query, an
  // unpublished course, or a course whose price is genuinely zero?
  // Those three look identical from the outside, which is exactly how
  // the first version of this page wasted a round of testing.
  const profile = await getCurrentProfile();
  const isStaff =
    profile !== null &&
    ["admin", "content_manager", "support"].includes(profile.role);

  const pricedCourses = courseRows.filter((c) => c.price_amount > 0).length;
  const allCourses = isStaff
    ? await db
        .from("courses")
        .select("id, status, price_amount")
        .returns<{ id: string; status: string; price_amount: number }[]>()
    : null;

  return (
    <div className="space-y-14">
      <section>
        <h1 className="text-3xl font-semibold tracking-tight">
          Choose your access
        </h1>
        <p className="mt-3 max-w-2xl text-muted-foreground">
          Pay once here, then open the Know Thyself app and sign in with the
          same email. Everything you have bought is already waiting.
        </p>
      </section>

      {isStaff && (
        <div className="rounded-lg border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900">
          <p className="font-semibold">
            Staff diagnostic — only you can see this
          </p>
          <ul className="mt-2 list-disc space-y-1 pl-5">
            <li>
              Membership plans marked active: <strong>{planRows.length}</strong>
              {planRows.length === 0 &&
                " — nothing to sell. Admin → Membership, mark a plan active."}
            </li>
            <li>
              Published courses: <strong>{courseRows.length}</strong>, of which{" "}
              <strong>{pricedCourses}</strong> have a price above zero.
              {courseRows.length > 0 && pricedCourses === 0 && (
                <>
                  {" "}
                  A course priced at ₹0 is free, so it shows without a buy
                  button — that is the page working, not failing. Set a price
                  in Admin → Courses → Edit.
                </>
              )}
            </li>
            {allCourses?.data && (
              <li>
                All courses in the database:{" "}
                <strong>{allCourses.data.length}</strong> (
                {allCourses.data.filter((c) => c.status === "published").length}{" "}
                published,{" "}
                {allCourses.data.filter((c) => c.status === "draft").length}{" "}
                draft,{" "}
                {allCourses.data.filter((c) => c.status === "archived").length}{" "}
                archived). Only published ones can appear here.
              </li>
            )}
            <li>
              Upcoming priced live sessions:{" "}
              <strong>{sessionRows.length}</strong>
            </li>
          </ul>
          <p className="mt-2 text-xs">
            Prices are stored in paise for courses and sessions, and in rupees
            for membership plans. A course showing ₹4.99 instead of ₹499 would
            mean that conversion is wrong somewhere.
          </p>
        </div>
      )}

      {failures.length > 0 && (
        <div className="rounded-lg border border-destructive/40 bg-destructive/5 p-4 text-sm">
          <p className="font-medium text-destructive">
            Some of this page could not be loaded.
          </p>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-muted-foreground">
            {failures.map((f) => (
              <li key={f}>{f}</li>
            ))}
          </ul>
        </div>
      )}

      {empty && failures.length === 0 && (
        <div className="rounded-lg border p-5 text-sm text-muted-foreground">
          <p className="font-medium text-foreground">
            Nothing is on sale at the moment.
          </p>
          <p className="mt-2">
            If that is unexpected, the usual causes are: no membership plan is
            marked active (Admin → Membership), no course has status
            &ldquo;published&rdquo; (Admin → Courses), and no upcoming live
            session has a price on it.
          </p>
        </div>
      )}

      {planRows.length > 0 && (
        <section className="space-y-5">
          <div>
            <h2 className="text-xl font-semibold">Membership</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Unlocks every guided meditation and talk in the library.
            </p>
          </div>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {planRows.map((plan) => (
              <Card key={plan.id}>
                <CardContent className="flex h-full flex-col gap-3 p-5">
                  <h3 className="font-semibold">{plan.name}</h3>
                  {plan.description && (
                    <p className="text-sm text-muted-foreground">
                      {plan.description}
                    </p>
                  )}
                  <p className="mt-auto pt-2 text-2xl font-semibold">
                    {/* Plans store rupees; courses and sessions store
                        paise. Getting this backwards prices a ₹499 plan
                        at ₹4.99, which Razorpay would happily charge. */}
                    {formatPrice(plan.price, plan.currency)}
                    <span className="ml-1 text-sm font-normal text-muted-foreground">
                      / {plan.billing_interval.replace("ly", "")}
                    </span>
                  </p>
                  <BuyButton target={{ kind: "plan", id: plan.id }} />
                </CardContent>
              </Card>
            ))}
          </div>
        </section>
      )}

      {courseRows.length > 0 && (
        <section className="space-y-5">
          <div>
            <h2 className="text-xl font-semibold">Courses</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Bought once, yours for good.
            </p>
          </div>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {courseRows.map((course) => (
              <Card key={course.id} className="overflow-hidden">
                {course.cover_image_url && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={course.cover_image_url}
                    alt=""
                    className="aspect-video w-full object-cover"
                  />
                )}
                <CardContent className="flex h-full flex-col gap-3 p-5">
                  <h3 className="font-semibold">{course.title}</h3>
                  {course.description && (
                    <p className="line-clamp-3 text-sm text-muted-foreground">
                      {course.description}
                    </p>
                  )}
                  {course.price_amount > 0 ? (
                    <>
                      <p className="mt-auto pt-2 text-2xl font-semibold">
                        {formatPrice(
                          course.price_amount / 100,
                          course.currency,
                        )}
                      </p>
                      <BuyButton target={{ kind: "course", id: course.id }} />
                    </>
                  ) : (
                    <>
                      <p className="mt-auto pt-2 text-2xl font-semibold">
                        Free
                      </p>
                      {/* No buy button, because there is nothing to buy.
                          mint-checkout-token would answer for it, and
                          the webhook grants a free course by row insert
                          rather than by payment — sending someone to
                          Razorpay for ₹0 has no path back. */}
                      <p className="text-sm text-muted-foreground">
                        Open the app and sign in — this one is already yours.
                      </p>
                    </>
                  )}
                </CardContent>
              </Card>
            ))}
          </div>
        </section>
      )}

      {sessionRows.length > 0 && (
        <section className="space-y-5">
          <div>
            <h2 className="text-xl font-semibold">Live sessions</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              A seat at an upcoming session. Seats are limited.
            </p>
          </div>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {sessionRows.map((session) => (
              <Card key={session.id}>
                <CardContent className="flex h-full flex-col gap-3 p-5">
                  <h3 className="font-semibold">{session.title}</h3>
                  <p className="text-sm text-muted-foreground">
                    {new Date(session.starts_at).toLocaleString("en-IN", {
                      dateStyle: "medium",
                      timeStyle: "short",
                      timeZone: "Asia/Kolkata",
                    })}{" "}
                    IST
                  </p>
                  {session.description && (
                    <p className="line-clamp-3 text-sm text-muted-foreground">
                      {session.description}
                    </p>
                  )}
                  <p className="mt-auto pt-2 text-2xl font-semibold">
                    {formatPrice(
                      (session.price_amount ?? 0) / 100,
                      session.currency,
                    )}
                  </p>
                  <BuyButton target={{ kind: "session", id: session.id }} />
                </CardContent>
              </Card>
            ))}
          </div>
        </section>
      )}

      <section className="rounded-lg border p-5 text-sm text-muted-foreground">
        <p>
          Already bought something? You do not need to buy it again — open the
          app and sign in with the same email.{" "}
          <Link href="/store/signin" className="underline hover:text-foreground">
            Sign in here
          </Link>{" "}
          to see what your account already has.
        </p>
      </section>
    </div>
  );
}

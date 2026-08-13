import Link from "next/link";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient as createUserClient } from "@/lib/supabase/server";
import { getCurrentProfile } from "@/lib/auth";
import { legal } from "@/lib/legal";
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

export default async function StorePage({
  searchParams,
}: {
  searchParams: Promise<{ debug?: string }>;
}) {
  const { debug } = await searchParams;
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
  const {
    data: { user: buyer },
  } = await createUserClient().auth.getUser();
  const buyerEmail = buyer?.email ?? null;

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
    <div className="space-y-12">
      {/* ── Hero ─────────────────────────────────────────────── */}
      <section>
        <p className="text-xs font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Know Thyself
        </p>
        <h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">
          Choose your access
        </h1>
        <p className="mt-3 max-w-xl text-muted-foreground">
          Pay here, then open the app and sign in with the same email.
          Everything you have bought is already waiting.
        </p>

        {/* The account is stated up here rather than in a panel at the
            foot of the page. Access is granted to the account that pays,
            so which one you are signed into is a thing to check before
            buying, not after. */}
        {buyerEmail ? (
          <p className="mt-5 inline-flex flex-wrap items-center gap-x-2 rounded-full bg-secondary px-4 py-2 text-sm">
            <span className="text-muted-foreground">Buying as</span>
            <span className="font-medium">{buyerEmail}</span>
          </p>
        ) : (
          <p className="mt-5 text-sm text-muted-foreground">
            Already bought something?{" "}
            <Link href="/store/signin" className="font-medium text-foreground underline underline-offset-4">
              Sign in
            </Link>{" "}
            — you never need to buy the same thing twice.
          </p>
        )}
      </section>

      {debug === "1" && (
        <pre className="overflow-x-auto rounded-lg border bg-muted p-4 text-xs">
          {JSON.stringify(
            {
              errors: {
                plans: plans.error?.message ?? null,
                courses: courses.error?.message ?? null,
                sessions: sessions.error?.message ?? null,
              },
              counts: {
                plans: planRows.length,
                courses: courseRows.length,
                sessions: sessionRows.length,
              },
              courses: courseRows.map((c) => ({
                title: c.title,
                price_amount: c.price_amount,
                price_type: typeof c.price_amount,
                gt_zero: c.price_amount > 0,
                currency: c.currency,
              })),
              plans: planRows.map((p) => ({
                name: p.name,
                price: p.price,
                price_type: typeof p.price,
                currency: p.currency,
              })),
            },
            null,
            2,
          )}
        </pre>
      )}

      {isStaff && (
        <div className="rounded-lg border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900">
          <p className="font-semibold">Staff diagnostic — only you can see this</p>
          <ul className="mt-2 list-disc space-y-1 pl-5">
            <li>
              Membership plans marked active: <strong>{planRows.length}</strong>
              {planRows.length === 0 &&
                " — nothing to sell. Admin → Membership, mark a plan active."}
            </li>
            <li>
              Published courses: <strong>{courseRows.length}</strong>, of which{" "}
              <strong>{pricedCourses}</strong> have a price above zero.
            </li>
            {allCourses?.data && (
              <li>
                All courses in the database:{" "}
                <strong>{allCourses.data.length}</strong> (
                {allCourses.data.filter((c) => c.status === "published").length}{" "}
                published,{" "}
                {allCourses.data.filter((c) => c.status === "draft").length} draft,{" "}
                {allCourses.data.filter((c) => c.status === "archived").length}{" "}
                archived). Only published ones can appear here.
              </li>
            )}
            <li>
              Upcoming priced live sessions: <strong>{sessionRows.length}</strong>
            </li>
          </ul>
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

      {/* ── Membership ───────────────────────────────────────── */}
      {planRows.length > 0 && (
        <section>
          <SectionHeading
            title="Membership"
            subtitle="Unlocks every guided meditation and talk in the library."
          />
          <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
            {planRows.map((plan) => (
              <Card key={plan.id} className="flex flex-col">
                <CardContent className="flex flex-1 flex-col p-6">
                  <h3 className="text-lg font-semibold">{plan.name}</h3>
                  {plan.description && (
                    <p className="mt-2 line-clamp-3 text-sm text-muted-foreground">
                      {plan.description}
                    </p>
                  )}
                  <PriceBlock
                    /* Plans store rupees; courses and sessions store paise.
                       Getting this backwards prices a ₹499 plan at ₹4.99,
                       which Razorpay would charge without complaint. */
                    price={formatPrice(plan.price, plan.currency)}
                    note={`per ${plan.billing_interval.replace("ly", "")}`}
                  />
                  <BuyButton target={{ kind: "plan", id: plan.id }} />
                </CardContent>
              </Card>
            ))}
          </div>
        </section>
      )}

      {/* ── Courses ──────────────────────────────────────────── */}
      {courseRows.length > 0 && (
        <section>
          <SectionHeading title="Courses" subtitle="Bought once, yours for good." />
          <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
            {courseRows.map((course) => (
              // flex-col on the Card, flex-1 on the content — NOT h-full
              // on the content. h-full resolved to the full stretched
              // height of the grid cell, so the content box started below
              // the cover image and ran that same height again, putting
              // the price and the button outside the card's own
              // overflow-hidden boundary. They rendered and were clipped,
              // which looked exactly like a branch that never ran.
              <Card key={course.id} className="flex flex-col overflow-hidden">
                {course.cover_image_url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={course.cover_image_url}
                    alt=""
                    className="aspect-video w-full object-cover"
                  />
                ) : (
                  // A tinted panel rather than nothing, so a course with
                  // no artwork still lines up with the ones that have it.
                  <div className="aspect-video w-full bg-secondary" />
                )}
                <CardContent className="flex flex-1 flex-col p-6">
                  <h3 className="text-lg font-semibold">{course.title}</h3>
                  {course.description && (
                    <p className="mt-2 line-clamp-2 text-sm text-muted-foreground">
                      {course.description}
                    </p>
                  )}
                  {course.price_amount > 0 ? (
                    <>
                      <PriceBlock
                        price={formatPrice(course.price_amount / 100, course.currency)}
                        note="one-time"
                      />
                      <BuyButton target={{ kind: "course", id: course.id }} />
                    </>
                  ) : (
                    <>
                      <PriceBlock price="Free" />
                      {/* No buy button, because there is nothing to buy.
                          The webhook grants a free course by row insert
                          rather than by payment, so a ₹0 Razorpay order
                          has no path back. */}
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

      {/* ── Live sessions ────────────────────────────────────── */}
      {sessionRows.length > 0 && (
        <section>
          <SectionHeading
            title="Live sessions"
            subtitle="A seat at an upcoming session. Seats are limited."
          />
          <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
            {sessionRows.map((session) => (
              <Card key={session.id} className="flex flex-col">
                <CardContent className="flex flex-1 flex-col p-6">
                  <p className="inline-flex w-fit rounded-full bg-secondary px-3 py-1 text-xs font-medium">
                    {new Date(session.starts_at).toLocaleString("en-IN", {
                      dateStyle: "medium",
                      timeStyle: "short",
                      timeZone: "Asia/Kolkata",
                    })}{" "}
                    IST
                  </p>
                  <h3 className="mt-3 text-lg font-semibold">{session.title}</h3>
                  {session.description && (
                    <p className="mt-2 line-clamp-2 text-sm text-muted-foreground">
                      {session.description}
                    </p>
                  )}
                  <PriceBlock
                    price={formatPrice(
                      (session.price_amount ?? 0) / 100,
                      session.currency,
                    )}
                    note="per seat"
                  />
                  <BuyButton target={{ kind: "session", id: session.id }} />
                </CardContent>
              </Card>
            ))}
          </div>
        </section>
      )}

      {/* ── What happens next ────────────────────────────────── */}
      {!empty && (
        <section className="rounded-2xl border bg-card p-6 sm:p-8">
          <h2 className="text-lg font-semibold">After you pay</h2>
          <ol className="mt-5 grid gap-6 sm:grid-cols-3">
            {[
              ["1", "Pay on this page", "Card, UPI or net banking, through Razorpay."],
              ["2", "Get the app", "Search the App Store or Play Store for Know Thyself."],
              ["3", "Sign in", "Use the same email you paid with, and it is already unlocked."],
            ].map(([n, title, body]) => (
              <li key={n} className="flex gap-3">
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-secondary text-sm font-semibold">
                  {n}
                </span>
                <span>
                  <span className="block font-medium">{title}</span>
                  <span className="mt-1 block text-sm text-muted-foreground">
                    {body}
                  </span>
                </span>
              </li>
            ))}
          </ol>
          <p className="mt-6 text-sm text-muted-foreground">
            Something not right? Write to{" "}
            <a
              href={`mailto:${legal.email}`}
              className="font-medium text-foreground underline underline-offset-4"
            >
              {legal.email}
            </a>
            .
          </p>
        </section>
      )}
    </div>
  );
}

/// One heading treatment for all three sections, so they read as a set
/// rather than three variations on a theme.
function SectionHeading({
  title,
  subtitle,
}: {
  title: string;
  subtitle: string;
}) {
  return (
    <div className="mb-5">
      <h2 className="text-xl font-semibold tracking-tight">{title}</h2>
      <p className="mt-1 text-sm text-muted-foreground">{subtitle}</p>
    </div>
  );
}

/// Pinned to the bottom of whatever card it is in, so prices line up
/// across a row no matter how long the titles and descriptions above
/// them run.
function PriceBlock({ price, note }: { price: string; note?: string }) {
  return (
    <div className="mt-auto flex items-baseline gap-2 pb-4 pt-6">
      <span className="text-2xl font-semibold">{price}</span>
      {note && <span className="text-sm text-muted-foreground">{note}</span>}
    </div>
  );
}

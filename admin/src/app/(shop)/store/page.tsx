import Link from "next/link";
import { createAdminClient } from "@/lib/supabase/admin";
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
    db
      .from("courses")
      .select("id, title, description, price_amount, currency, cover_image_url")
      .eq("status", "published")
      .gt("price_amount", 0)
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
  const empty =
    planRows.length === 0 &&
    courseRows.length === 0 &&
    sessionRows.length === 0;

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

      {empty && (
        <p className="text-muted-foreground">
          Nothing is on sale at the moment. Please check back shortly.
        </p>
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
                  <p className="mt-auto pt-2 text-2xl font-semibold">
                    {formatPrice(course.price_amount / 100, course.currency)}
                  </p>
                  <BuyButton target={{ kind: "course", id: course.id }} />
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

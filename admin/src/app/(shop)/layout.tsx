import Link from "next/link";
import { legal } from "@/lib/legal";
import { createClient } from "@/lib/supabase/server";
import { AccountNav } from "./account-nav";

/// Frame for the public storefront.
///
/// Separate from (dashboard) for the same reason the policy pages are:
/// everyone this exists for is signed out. It is also the reason the
/// storefront had to be built at all — the checkout page can only be
/// reached with a token minted for a signed-in user, so until now the
/// only way to buy anything was from inside the app. That is fine on
/// Android and impossible on iOS, where the app may not sell.
export default async function ShopLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const {
    data: { user },
  } = await createClient().auth.getUser();

  return (
    <div className="flex min-h-screen flex-col bg-background">
      <header className="border-b">
        <div className="mx-auto flex w-full max-w-5xl items-center justify-between px-5 py-4">
          <Link href="/store" className="font-semibold">
            {legal.tradingName}
          </Link>
          <nav className="flex items-center gap-x-5 text-sm text-muted-foreground">
            <Link href="/store" className="hover:text-foreground">
              Browse
            </Link>
            <AccountNav email={user?.email ?? null} />
          </nav>
        </div>
      </header>

      <main className="mx-auto w-full max-w-5xl flex-1 px-5 py-10">
        {children}
      </main>

      <footer className="border-t">
        <div className="mx-auto w-full max-w-5xl px-5 py-6 text-sm text-muted-foreground">
          <nav className="flex flex-wrap gap-x-5 gap-y-1">
            <Link href="/terms" className="hover:text-foreground">
              Terms
            </Link>
            <Link href="/privacy" className="hover:text-foreground">
              Privacy
            </Link>
            <Link href="/refunds" className="hover:text-foreground">
              Refunds
            </Link>
            <Link href="/contact" className="hover:text-foreground">
              Contact
            </Link>
          </nav>
          <p className="mt-4">
            {legal.businessName} · {legal.address}
          </p>
          <p className="mt-1">
            {legal.email} · {legal.phone}
          </p>
        </div>
      </footer>
    </div>
  );
}

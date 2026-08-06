import Link from "next/link";
import { legal } from "@/lib/legal";

/// Shared frame for the public policy pages.
///
/// Deliberately outside (dashboard): these have to be readable by a
/// customer, a Razorpay reviewer and an app-store reviewer, none of whom
/// have a login. Anything that required one would be invisible to
/// exactly the people it exists for.
const LINKS = [
  { href: "/terms", label: "Terms" },
  { href: "/privacy", label: "Privacy" },
  { href: "/refunds", label: "Refunds" },
  { href: "/contact", label: "Contact" },
];

export default function LegalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-background">
      <header className="border-b">
        <div className="mx-auto flex max-w-3xl flex-wrap items-center gap-x-6 gap-y-2 px-5 py-4">
          <span className="font-semibold">{legal.tradingName}</span>
          <nav className="flex flex-wrap gap-x-5 gap-y-1 text-sm text-muted-foreground">
            {LINKS.map((l) => (
              <Link key={l.href} href={l.href} className="hover:text-foreground">
                {l.label}
              </Link>
            ))}
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-5 py-10">{children}</main>

      <footer className="border-t">
        <div className="mx-auto max-w-3xl px-5 py-6 text-sm text-muted-foreground">
          <p>
            {legal.businessName} · {legal.address}
          </p>
          <p className="mt-1">
            {legal.email} · {legal.phone}
          </p>
          <p className="mt-3 text-xs">Last updated {legal.lastUpdated}</p>
        </div>
      </footer>
    </div>
  );
}

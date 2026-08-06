/// Minimal typography for the policy pages.
///
/// Hand-rolled rather than @tailwindcss/typography: four static pages do
/// not justify a dependency, and the prose plugin's defaults would need
/// overriding for the dark theme anyway.
export function H1({ children }: { children: React.ReactNode }) {
  return <h1 className="mb-2 text-3xl font-semibold tracking-tight">{children}</h1>;
}

export function Lead({ children }: { children: React.ReactNode }) {
  return <p className="mb-8 text-muted-foreground">{children}</p>;
}

export function H2({ children }: { children: React.ReactNode }) {
  return <h2 className="mb-3 mt-8 text-lg font-semibold">{children}</h2>;
}

export function P({ children }: { children: React.ReactNode }) {
  return <p className="mb-4 leading-relaxed text-muted-foreground">{children}</p>;
}

export function UL({ children }: { children: React.ReactNode }) {
  return (
    <ul className="mb-4 list-disc space-y-2 pl-5 leading-relaxed text-muted-foreground">
      {children}
    </ul>
  );
}

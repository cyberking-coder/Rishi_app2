import { createAdminClient } from "@/lib/supabase/admin";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export const dynamic = "force-dynamic";

interface VerifyResult {
  valid: boolean;
  revoked?: boolean;
  certificate_number?: string;
  recipient_name?: string | null;
  course_title?: string;
  issued_at?: string;
}

/**
 * Public certificate verification.
 *
 * Reads through verify_certificate(), which returns only what a verifier
 * needs — name, course, date, number — and never the holder's user id,
 * email, or the course id. So a certificate number shared with an
 * employer discloses nothing beyond what the certificate itself already
 * states.
 */
export default async function VerifyPage({
  searchParams,
}: {
  searchParams: Promise<{ number?: string }>;
}) {
  const { number } = await searchParams;
  let result: VerifyResult | null = null;

  if (number?.trim()) {
    const db = createAdminClient();
    const { data } = await db.rpc("verify_certificate", {
      p_number: number.trim(),
    });
    result = (data as VerifyResult) ?? { valid: false };
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>Verify a certificate</CardTitle>
        </CardHeader>
        <CardContent className="space-y-5">
          <form className="flex gap-2" action="/verify">
            <Input
              name="number"
              defaultValue={number ?? ""}
              placeholder="KT-2026-A1B2C3D4"
              autoComplete="off"
            />
            <Button type="submit">Check</Button>
          </form>

          {result && (
            <div className="rounded-lg border p-4">
              {result.valid ? (
                <>
                  <Badge variant="success">Valid certificate</Badge>
                  <dl className="mt-4 space-y-2 text-sm">
                    <Row label="Awarded to" value={result.recipient_name ?? "—"} />
                    <Row label="Course" value={result.course_title ?? "—"} />
                    <Row
                      label="Issued"
                      value={
                        result.issued_at
                          ? new Date(result.issued_at).toLocaleDateString(
                              "en-IN",
                              { day: "numeric", month: "long", year: "numeric" },
                            )
                          : "—"
                      }
                    />
                    <Row
                      label="Number"
                      value={result.certificate_number ?? "—"}
                    />
                  </dl>
                </>
              ) : result.revoked ? (
                <>
                  <Badge variant="destructive">Withdrawn</Badge>
                  <p className="mt-3 text-sm text-muted-foreground">
                    This certificate was issued but has since been withdrawn,
                    and is no longer valid.
                  </p>
                </>
              ) : (
                <>
                  <Badge variant="destructive">Not found</Badge>
                  <p className="mt-3 text-sm text-muted-foreground">
                    No certificate matches that number. Check it was copied in
                    full, including the KT- prefix.
                  </p>
                </>
              )}
            </div>
          )}

          <p className="text-xs text-muted-foreground">
            Certificates are issued by Know Thyself when a learner completes
            every lesson and passes every assessment in a course.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="text-right font-medium">{value}</dd>
    </div>
  );
}

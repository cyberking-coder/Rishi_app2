import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { PageHeader } from "@/components/page-header";
import { CertificateRevokeButton } from "@/components/courses/certificate-revoke-button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDate } from "@/lib/utils";
import type { Certificate } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function CertificatesPage() {
  const supabase = createClient();

  const { data: certificates } = await supabase
    .from("certificates")
    .select("*")
    .order("issued_at", { ascending: false })
    .returns<Certificate[]>();

  const rows = certificates ?? [];

  // Names are snapshotted onto the certificate at issue time, but an
  // account that has since set a display name is worth showing too —
  // and email is the only reliable way to tell two students apart.
  const emailById = new Map<string, string>();
  try {
    const admin = createAdminClient();
    const { data: authList } = await admin.auth.admin.listUsers({
      page: 1,
      perPage: 1000,
    });
    for (const u of authList?.users ?? []) {
      if (u.email) emailById.set(u.id, u.email);
    }
  } catch {
    // Best-effort: without it the list still identifies holders by the
    // name printed on the certificate.
  }

  const live = rows.filter((c) => c.revoked_at === null).length;

  return (
    <div>
      <PageHeader
        title="Certificates"
        description="Issued automatically when a learner finishes every lesson and passes every quiz in a course."
      />

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Certificate no.</TableHead>
                <TableHead>Holder</TableHead>
                <TableHead>Course</TableHead>
                <TableHead>Issued</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="w-28" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={6}
                    className="py-8 text-center text-muted-foreground"
                  >
                    No certificates issued yet.
                  </TableCell>
                </TableRow>
              ) : (
                rows.map((c) => (
                  <TableRow key={c.id}>
                    <TableCell className="font-mono text-xs">
                      {c.certificate_number}
                    </TableCell>
                    <TableCell className="font-medium">
                      <div>{c.recipient_name ?? "—"}</div>
                      <div className="text-xs font-normal text-muted-foreground">
                        {emailById.get(c.user_id) ?? "—"}
                      </div>
                    </TableCell>
                    <TableCell>{c.course_title}</TableCell>
                    <TableCell className="text-muted-foreground">
                      {formatDate(c.issued_at)}
                    </TableCell>
                    <TableCell>
                      {c.revoked_at ? (
                        <Badge variant="destructive">Revoked</Badge>
                      ) : (
                        <Badge variant="success">Valid</Badge>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <CertificateRevokeButton
                        certificateId={c.id}
                        revoked={c.revoked_at !== null}
                        holder={c.recipient_name ?? c.certificate_number}
                      />
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <p className="mt-3 text-xs text-muted-foreground">
        {live} valid · {rows.length - live} revoked. A revoked certificate
        keeps its number and still resolves on the public verification page —
        as invalid. Deleting instead would make a withdrawn credential
        indistinguishable from a forged number.
      </p>
    </div>
  );
}

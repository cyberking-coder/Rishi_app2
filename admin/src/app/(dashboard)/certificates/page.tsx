import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { PageHeader } from "@/components/page-header";
import { CertificateRevokeButton } from "@/components/courses/certificate-revoke-button";
import { CertificateNameCell } from "@/components/courses/certificate-name-cell";
import { CertificateTemplateEditor } from "@/components/courses/certificate-template-editor";
import { CourseDesignPicker } from "@/components/courses/course-design-picker";
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
import type { Certificate, Course } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function CertificatesPage({
  searchParams,
}: {
  searchParams: Promise<{ course?: string }>;
}) {
  const { course: selectedCourseId } = await searchParams;
  const supabase = createClient();

  // Certificate artwork is per course, so designing it needs a course
  // chosen. It lives here rather than on the course page because it is
  // a certificate concern — an admin thinking about certificates
  // shouldn't have to know which course page to open to change how they
  // look.
  const { data: courses } = await supabase
    .from("courses")
    .select("*")
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: false })
    .returns<Course[]>();

  const designCourse =
    (courses ?? []).find((c) => c.id === selectedCourseId) ??
    (courses ?? [])[0];

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
        description="Issued automatically when a learner finishes every lesson in a course."
      />

      {designCourse ? (
        <>
          <CourseDesignPicker
            courses={(courses ?? []).map((c) => ({ id: c.id, title: c.title }))}
            selectedId={designCourse.id}
          />
          <CertificateTemplateEditor course={designCourse} />
        </>
      ) : (
        <p className="mb-6 text-sm text-muted-foreground">
          Create a course before designing a certificate.
        </p>
      )}

      <h2 className="mb-3 mt-8 text-lg font-semibold">Issued certificates</h2>

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
                      <CertificateNameCell
                        certificateId={c.id}
                        name={c.recipient_name}
                        email={emailById.get(c.user_id) ?? "—"}
                      />
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

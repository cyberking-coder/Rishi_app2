import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { CourseFormDialog } from "@/components/courses/course-form-dialog";
import { CourseActions } from "@/components/courses/course-actions";
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
import type { Category, Course, CourseStatus } from "@/lib/types";

export const dynamic = "force-dynamic";

/** Courses use their own status set (no 'processing'), so this doesn't
 *  reuse ContentStatusBadge, which is typed to ContentStatus. */
function CourseStatusBadge({ status }: { status: CourseStatus }) {
  const variant =
    status === "published"
      ? "success"
      : status === "archived"
        ? "secondary"
        : "outline";
  return <Badge variant={variant}>{status}</Badge>;
}

interface CourseRow extends Course {
  course_modules: { id: string }[];
}

/** How many people have bought this course, against its seat limit if it
 *  has one — the two numbers are only meaningful together when seats are
 *  capped, and the cap is what decides whether checkout stays open. */
function EnrolledCell({
  count,
  seatLimit,
}: {
  count: number;
  seatLimit: number | null;
}) {
  if (seatLimit === null) {
    return (
      <span className={count === 0 ? "text-muted-foreground" : "font-medium"}>
        {count}
      </span>
    );
  }

  const soldOut = count >= seatLimit;
  return (
    <span className="flex items-center gap-1.5">
      <span className="font-medium">
        {count}
        <span className="text-muted-foreground">/{seatLimit}</span>
      </span>
      {soldOut && <Badge variant="destructive">Sold out</Badge>}
    </span>
  );
}

export default async function CoursesPage() {
  const supabase = createClient();

  const [{ data: courses }, { data: categories }, { data: purchases }] =
    await Promise.all([
      supabase
        .from("courses")
        .select("*, course_modules(id)")
        .order("sort_order", { ascending: true })
        .order("created_at", { ascending: false })
        .returns<CourseRow[]>(),
      supabase
        .from("categories")
        .select("*")
        .order("name", { ascending: true })
        .returns<Category[]>(),
      // Enrolments. Fetched as a flat list and counted here rather than
      // embedded on `courses`, because a failing embed takes the whole
      // course query down with it — the same way the modules list
      // vanished once before.
      supabase
        .from("course_purchases")
        .select("course_id, user_id, expires_at")
        // Revoked enrolments are dated in the past, not deleted, so they
        // have to be excluded here or a course would keep reporting a
        // seat as taken after its student lost access.
        .eq("status", "paid")
        .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
        .returns<{ course_id: string; user_id: string }[]>(),
    ]);

  const categoryNameById = new Map(
    (categories ?? []).map((c) => [c.id, c.name]),
  );

  // Distinct buyers, not rows: a refund-and-rebuy leaves two paid rows
  // for one person, and counting those twice would overstate the class.
  const buyersByCourse = new Map<string, Set<string>>();
  for (const p of purchases ?? []) {
    const set = buyersByCourse.get(p.course_id) ?? new Set<string>();
    set.add(p.user_id);
    buyersByCourse.set(p.course_id, set);
  }

  return (
    <div>
      <PageHeader
        title="Courses"
        description="Build courses from modules and lessons. Lessons reuse your existing audio library."
        action={<CourseFormDialog categories={categories ?? []} />}
      />

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Title</TableHead>
                <TableHead>Category</TableHead>
                <TableHead>Modules</TableHead>
                <TableHead>Enrolled</TableHead>
                <TableHead>Access</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Created</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(courses ?? []).length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={8}
                    className="py-8 text-center text-muted-foreground"
                  >
                    No courses yet.
                  </TableCell>
                </TableRow>
              ) : (
                (courses ?? []).map((c) => (
                  <TableRow key={c.id}>
                    <TableCell className="font-medium">
                      <Link
                        href={`/courses/${c.id}`}
                        className="hover:underline"
                      >
                        {c.title}
                      </Link>
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {c.category_id
                        ? (categoryNameById.get(c.category_id) ?? "—")
                        : "—"}
                    </TableCell>
                    <TableCell>{c.course_modules?.length ?? 0}</TableCell>
                    <TableCell>
                      <EnrolledCell
                        count={buyersByCourse.get(c.id)?.size ?? 0}
                        seatLimit={c.seat_limit}
                      />
                    </TableCell>
                    <TableCell>
                      <Badge variant={c.is_premium ? "default" : "outline"}>
                        {c.is_premium ? "Premium" : "Free"}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <CourseStatusBadge status={c.status} />
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {formatDate(c.created_at)}
                    </TableCell>
                    <TableCell>
                      <CourseActions
                        courseId={c.id}
                        status={c.status}
                        isPremium={c.is_premium}
                      />
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}

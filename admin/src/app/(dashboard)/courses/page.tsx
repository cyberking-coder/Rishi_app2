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

export default async function CoursesPage() {
  const supabase = createClient();

  const [{ data: courses }, { data: categories }] = await Promise.all([
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
  ]);

  const categoryNameById = new Map(
    (categories ?? []).map((c) => [c.id, c.name]),
  );

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
                    colSpan={7}
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

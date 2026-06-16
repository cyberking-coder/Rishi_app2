import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { CreateCategoryDialog } from "@/components/categories/create-category-dialog";
import { DeleteCategoryButton } from "@/components/categories/delete-category-button";
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
import type { Category } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function CategoriesPage() {
  const supabase = createClient();
  const { data: categories } = await supabase
    .from("categories")
    .select("*")
    .order("sort_order", { ascending: true })
    .returns<Category[]>();

  return (
    <div>
      <PageHeader
        title="Categories"
        description="Organize content into browseable groups."
        action={<CreateCategoryDialog />}
      />

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Name</TableHead>
                <TableHead>Slug</TableHead>
                <TableHead>Applies to</TableHead>
                <TableHead>Order</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(categories ?? []).length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="py-8 text-center text-muted-foreground">
                    No categories yet.
                  </TableCell>
                </TableRow>
              ) : (
                (categories ?? []).map((c) => (
                  <TableRow key={c.id}>
                    <TableCell className="font-medium">{c.name}</TableCell>
                    <TableCell className="text-muted-foreground">{c.slug}</TableCell>
                    <TableCell>
                      <Badge variant="outline" className="capitalize">
                        {c.content_type}
                      </Badge>
                    </TableCell>
                    <TableCell>{c.sort_order}</TableCell>
                    <TableCell>
                      <DeleteCategoryButton id={c.id} />
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

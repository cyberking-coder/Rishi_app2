"use client";

import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { deleteCategory } from "@/app/actions/categories";

export function DeleteCategoryButton({ id }: { id: string }) {
  const router = useRouter();

  async function onClick() {
    const result = await deleteCategory(id);
    if (!result.ok) return toast.error(result.error);
    toast.success("Category deleted");
    router.refresh();
  }

  return (
    <Button variant="ghost" size="icon" onClick={onClick}>
      <Trash2 className="h-4 w-4 text-destructive" />
    </Button>
  );
}

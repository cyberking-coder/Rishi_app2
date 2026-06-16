"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import { slugify } from "@/lib/utils";
import type { ActionResult } from "./users";

export interface CreateCategoryInput {
  name: string;
  description?: string;
  contentType: "video" | "audio" | "both";
  sortOrder: number;
}

export async function createCategory(
  input: CreateCategoryInput,
): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db.from("categories").insert({
    name: input.name,
    slug: slugify(input.name),
    description: input.description ?? null,
    content_type: input.contentType,
    sort_order: input.sortOrder,
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath("/categories");
  return { ok: true };
}

export async function deleteCategory(id: string): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db.from("categories").delete().eq("id", id);
  if (error) return { ok: false, error: error.message };
  revalidatePath("/categories");
  return { ok: true };
}

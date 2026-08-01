"use client";

import { useRouter } from "next/navigation";
import { Label } from "@/components/ui/label";
import { NativeOption, NativeSelect } from "@/components/ui/native-select";

/** Chooses which course's certificate artwork is being edited. Drives a
 *  query param rather than local state, so the server component below it
 *  re-renders with that course's saved layout. */
export function CourseDesignPicker({
  courses,
  selectedId,
}: {
  courses: { id: string; title: string }[];
  selectedId: string;
}) {
  const router = useRouter();

  return (
    <div className="mb-2 max-w-sm space-y-1.5">
      <Label htmlFor="design-course">Designing certificate for</Label>
      <NativeSelect
        id="design-course"
        value={selectedId}
        onChange={(e) => router.push(`/certificates?course=${e.target.value}`)}
      >
        {courses.map((c) => (
          <NativeOption key={c.id} value={c.id}>
            {c.title}
          </NativeOption>
        ))}
      </NativeSelect>
    </div>
  );
}

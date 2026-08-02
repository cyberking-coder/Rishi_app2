"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Pencil } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { updateCertificateRecipient } from "@/app/actions/certificates";

/**
 * The name printed on the certificate, editable in place.
 *
 * Highlighted when missing, because a blank name is what a learner sees
 * as "Student" on their own credential — a defect worth noticing from
 * the list rather than only from a complaint.
 */
export function CertificateNameCell({
  certificateId,
  name,
  email,
}: {
  certificateId: string;
  name: string | null;
  email: string;
}) {
  const router = useRouter();
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(name ?? "");
  const [busy, setBusy] = useState(false);

  async function save() {
    setBusy(true);
    try {
      const result = await updateCertificateRecipient(certificateId, value);
      if (!result.ok) return toast.error(result.error);
      toast.success("Name updated.");
      setEditing(false);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  if (editing) {
    return (
      <div className="flex items-center gap-1">
        <Input
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") void save();
            if (e.key === "Escape") setEditing(false);
          }}
          autoFocus
          className="h-8 w-44"
        />
        <Button size="sm" className="h-8" disabled={busy} onClick={save}>
          Save
        </Button>
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center gap-1">
        {name ? (
          <span>{name}</span>
        ) : (
          <span className="text-destructive">No name — shows as “Student”</span>
        )}
        <Button
          variant="ghost"
          size="icon"
          className="h-6 w-6"
          onClick={() => setEditing(true)}
          title="Edit the printed name"
        >
          <Pencil className="h-3 w-3" />
        </Button>
      </div>
      <div className="text-xs font-normal text-muted-foreground">{email}</div>
    </div>
  );
}

import { PageHeader } from "@/components/page-header";
import { listPopups } from "@/app/actions/config";
import { PopupConfigForm } from "@/components/settings/popup-config-form";

export const dynamic = "force-dynamic";

export default async function SettingsPage() {
  const popups = await listPopups();

  return (
    <div>
      <PageHeader
        title="Settings"
        description="Configure the in-app pop-ups shown to members."
      />
      <PopupConfigForm initial={popups} />
    </div>
  );
}

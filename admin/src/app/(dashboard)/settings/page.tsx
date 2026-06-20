import { PageHeader } from "@/components/page-header";
import { getPopupConfig } from "@/app/actions/config";
import { PopupConfigForm } from "@/components/settings/popup-config-form";

export const dynamic = "force-dynamic";

export default async function SettingsPage() {
  const config = await getPopupConfig();

  return (
    <div>
      <PageHeader
        title="Settings"
        description="Configure the in-app next-event pop-up shown to attendees."
      />
      <PopupConfigForm
        initial={
          config ?? {
            popup_enabled: false,
            popup_start_at: null,
            popup_title: null,
            popup_body: null,
            popup_image_url: null,
          }
        }
      />
    </div>
  );
}

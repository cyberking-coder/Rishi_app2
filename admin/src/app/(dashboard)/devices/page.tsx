import { createClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/page-header";
import { DeactivateDeviceButton } from "@/components/devices/device-actions";
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

export const dynamic = "force-dynamic";

interface DeviceWithUser {
  id: string;
  device_name: string | null;
  platform: string;
  is_active: boolean;
  last_seen_at: string;
  user_id: string;
  profiles: { display_name: string | null } | null;
}

export default async function DevicesPage() {
  const supabase = createClient();
  const { data: devices } = await supabase
    .from("devices")
    .select("id, device_name, platform, is_active, last_seen_at, user_id, profiles(display_name)")
    .order("last_seen_at", { ascending: false })
    .returns<DeviceWithUser[]>();

  return (
    <div>
      <PageHeader
        title="Device Management"
        description="One active device per account. Reset a device to let the user re-register on a new phone."
      />

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Device</TableHead>
                <TableHead>Platform</TableHead>
                <TableHead>User</TableHead>
                <TableHead>State</TableHead>
                <TableHead>Last seen</TableHead>
                <TableHead className="w-20" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {(devices ?? []).length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="py-8 text-center text-muted-foreground">
                    No devices registered.
                  </TableCell>
                </TableRow>
              ) : (
                (devices ?? []).map((d) => (
                  <TableRow key={d.id}>
                    <TableCell className="font-medium">
                      {d.device_name ?? "Unknown device"}
                    </TableCell>
                    <TableCell className="capitalize">{d.platform}</TableCell>
                    <TableCell className="text-muted-foreground">
                      {d.profiles?.display_name ?? d.user_id.slice(0, 8)}
                    </TableCell>
                    <TableCell>
                      {d.is_active ? (
                        <Badge variant="success">Active</Badge>
                      ) : (
                        <Badge variant="secondary">Inactive</Badge>
                      )}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {formatDate(d.last_seen_at)}
                    </TableCell>
                    <TableCell>
                      {d.is_active ? (
                        <DeactivateDeviceButton deviceId={d.id} />
                      ) : null}
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

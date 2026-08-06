import { PageHeader } from "@/components/page-header";
import { listPlans } from "@/app/actions/plans";
import { PlanFormDialog } from "@/components/plans/plan-form-dialog";
import { PlanActions } from "@/components/plans/plan-actions";
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

export const dynamic = "force-dynamic";

export default async function PlansPage() {
  const plans = await listPlans();
  const active = plans.filter((p) => p.is_active);

  return (
    <div>
      <PageHeader
        title="Membership plans"
        description="What the app sells under “Get Access Now”. Prices are in rupees and apply to payments made from now on — nobody inside an access window is re-charged or cut short."
        action={<PlanFormDialog />}
      />

      {active.length === 0 ? (
        <p className="mb-4 text-sm text-destructive">
          No active plan. The app cannot open checkout at all until one is
          available for purchase.
        </p>
      ) : active.length > 1 ? (
        <p className="mb-4 text-sm text-muted-foreground">
          {active.length} plans are active. The app offers the first one it
          finds, so keep a single plan on sale unless you have a reason not
          to.
        </p>
      ) : null}

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Plan</TableHead>
                <TableHead>Price</TableHead>
                <TableHead>Billing</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {plans.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-muted-foreground">
                    No plans yet.
                  </TableCell>
                </TableRow>
              ) : (
                plans.map((plan) => (
                  <TableRow key={plan.id}>
                    <TableCell>
                      <div className="font-medium">{plan.name}</div>
                      {plan.description && (
                        <div className="max-w-md text-xs text-muted-foreground">
                          {plan.description}
                        </div>
                      )}
                    </TableCell>
                    <TableCell className="font-medium">
                      ₹{plan.price}
                    </TableCell>
                    <TableCell className="capitalize text-muted-foreground">
                      {plan.billing_interval}
                    </TableCell>
                    <TableCell>
                      <Badge variant={plan.is_active ? "default" : "secondary"}>
                        {plan.is_active ? "On sale" : "Retired"}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-1">
                        <PlanFormDialog plan={plan} />
                        <PlanActions plan={plan} />
                      </div>
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

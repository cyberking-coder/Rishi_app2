-- Phase 3a: Razorpay payments core.
--
-- 1. Seed the first blanket-subscription plan. `subscriptions.plan_id` is
--    not null, so at least one plan must exist before a purchase is
--    possible. Price is stored in the plan's base currency unit (rupees,
--    not paise) to match the existing `numeric(10,2)` column convention.
insert into public.subscription_plans (name, description, price, currency, billing_interval, is_active)
values ('Rishi Mode', 'Full access to all premium content.', 199.00, 'INR', 'monthly', true)
on conflict (name) do nothing;

-- 2. Webhook replay protection. Razorpay (like most providers) can
-- redeliver the same webhook event more than once; this table is checked
-- before granting access so a redelivery is a no-op rather than a second
-- grant. `event_key` is a caller-constructed composite (event type +
-- payment id), since Razorpay's webhook payload has no single canonical
-- event id field to rely on alone.
create table public.webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  event_key text not null,
  created_at timestamptz not null default now()
);

create unique index uq_webhook_events_provider_key
  on public.webhook_events (provider, event_key);

alter table public.webhook_events enable row level security;

-- Only service_role (the webhook function) writes here, which bypasses
-- RLS entirely - this policy just lets admins inspect it for debugging.
create policy "webhook_events_admin_select"
  on public.webhook_events for select
  using (public.is_admin());

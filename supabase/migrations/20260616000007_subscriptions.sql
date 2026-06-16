create table public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  price numeric(10, 2) not null,
  currency text not null default 'USD',
  billing_interval text not null
    check (billing_interval in ('weekly', 'monthly', 'yearly')),
  features jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  plan_id uuid not null references public.subscription_plans (id),
  status text not null default 'trialing'
    check (status in ('trialing', 'active', 'past_due', 'canceled', 'expired')),
  payment_provider text not null,
  provider_subscription_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_subscriptions_user_id on public.subscriptions (user_id);
create index idx_subscriptions_status on public.subscriptions (status);
create unique index uq_subscriptions_provider_ref
  on public.subscriptions (payment_provider, provider_subscription_id);

create trigger trg_subscriptions_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid references public.subscriptions (id) on delete set null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  amount numeric(10, 2) not null,
  currency text not null default 'USD',
  provider text not null,
  provider_payment_id text not null,
  status text not null default 'pending'
    check (status in ('pending', 'succeeded', 'failed', 'refunded')),
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index uq_payments_provider_ref on public.payments (provider, provider_payment_id);
create index idx_payments_user_id on public.payments (user_id);
create index idx_payments_subscription_id on public.payments (subscription_id);

-- RLS
alter table public.subscription_plans enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payments enable row level security;

create policy "plans_select_active"
  on public.subscription_plans for select
  using (is_active or public.is_admin());

create policy "plans_admin_manage"
  on public.subscription_plans for all
  using (public.is_admin())
  with check (public.is_admin());

create policy "subscriptions_select_own_or_admin"
  on public.subscriptions for select
  using (user_id = auth.uid() or public.is_admin());

-- Writes happen only via service_role (payment webhooks / Edge Functions),
-- never directly from the client.
create policy "subscriptions_admin_manage"
  on public.subscriptions for all
  using (public.is_admin())
  with check (public.is_admin());

create policy "payments_select_own_or_admin"
  on public.payments for select
  using (user_id = auth.uid() or public.is_admin());

create policy "payments_admin_manage"
  on public.payments for all
  using (public.is_admin())
  with check (public.is_admin());

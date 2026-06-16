create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text,
  parent_id uuid references public.categories (id) on delete set null,
  content_type text not null default 'both'
    check (content_type in ('video', 'audio', 'both')),
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_categories_parent_id on public.categories (parent_id);
create index idx_categories_content_type on public.categories (content_type);

create trigger trg_categories_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

-- RLS
alter table public.categories enable row level security;

create policy "categories_select_all"
  on public.categories for select
  using (true);

create policy "categories_admin_manage"
  on public.categories for all
  using (public.is_admin())
  with check (public.is_admin());

-- Account deletion, without taking the accounts ledger with it.
--
-- Apple requires an app that creates accounts to let somebody delete
-- theirs from inside the app (Guideline 5.1.1(v)). Pointing them at an
-- email address does not satisfy it.
--
-- The obstacle is not the deletion, it is the cascade. profiles.id
-- references auth.users ON DELETE CASCADE, and every table below hangs
-- off profiles the same way — so deleting one auth user silently
-- destroys their course purchases, workshop registrations and
-- subscription records. Those are financial records. Indian tax law
-- expects them to be retainable for years, and Apple's own rule
-- explicitly permits keeping data required for legitimate legal
-- purposes.
--
-- So the money tables stop cascading and start forgetting instead: the
-- row survives, its user_id becomes null, and the billing name and
-- amount already stored on it keep the record meaningful for accounting.
-- Everything genuinely personal — profile, history, downloads, devices,
-- push tokens, chat — still cascades and is gone.

-- ---------------------------------------------------------------------------
-- Money rows outlive the account
-- ---------------------------------------------------------------------------
alter table public.course_purchases
  alter column user_id drop not null;
alter table public.course_purchases
  drop constraint if exists course_purchases_user_id_fkey;
alter table public.course_purchases
  add constraint course_purchases_user_id_fkey
  foreign key (user_id) references public.profiles (id) on delete set null;

alter table public.workshop_registrations
  alter column user_id drop not null;
alter table public.workshop_registrations
  drop constraint if exists workshop_registrations_user_id_fkey;
alter table public.workshop_registrations
  add constraint workshop_registrations_user_id_fkey
  foreign key (user_id) references public.profiles (id) on delete set null;

alter table public.subscriptions
  alter column user_id drop not null;
alter table public.subscriptions
  drop constraint if exists subscriptions_user_id_fkey;
alter table public.subscriptions
  add constraint subscriptions_user_id_fkey
  foreign key (user_id) references public.profiles (id) on delete set null;

-- The partial unique indexes on course_purchases and
-- workshop_registrations are unaffected: Postgres treats NULLs as
-- distinct, so any number of orphaned paid rows can coexist. And every
-- RLS policy on these tables compares user_id to auth.uid(), which a
-- null can never equal — an orphaned row is invisible to members and
-- visible to staff, which is exactly right for a record kept only for
-- the books.

-- ---------------------------------------------------------------------------
-- A note of what was deleted, without saying who
-- ---------------------------------------------------------------------------
-- Enough to answer "how many people left, and when" without keeping any
-- of the person. Deliberately holds no email, no name and no user id:
-- a deletion log that identifies the deleted defeats its own purpose.
create table if not exists public.account_deletions (
  id uuid primary key default gen_random_uuid(),
  deleted_at timestamptz not null default now(),
  -- 'user' when somebody deleted their own, 'admin' if staff did it for
  -- them after a support request.
  requested_by text not null default 'user'
    check (requested_by in ('user', 'admin')),
  -- Whether they had bought anything. Answers "are we losing paying
  -- customers or curious signups" with one boolean instead of a join
  -- onto records that no longer point anywhere.
  had_purchases boolean not null default false
);

alter table public.account_deletions enable row level security;

drop policy if exists "account_deletions_admin_read" on public.account_deletions;
create policy "account_deletions_admin_read"
  on public.account_deletions for select
  using (public.is_admin());

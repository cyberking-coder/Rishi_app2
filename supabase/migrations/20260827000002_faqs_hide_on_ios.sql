-- Withhold a help article from iOS.
--
-- WHY, AND WHEN THIS CHANGED
--
-- On 27 August 2026 Apple denied the External Link Account Entitlement
-- for com.anuragrishi.knowthyself, stating plainly that the app "does not
-- qualify as a reader app". That is Apple's own written record that the
-- Guideline 3.1.3(a) exemption — the basis on which 2.1.1 was approved
-- with no in-app purchase — does not, in their view, apply here.
--
-- Nothing about the app changed that day and the listing was not at
-- risk. What changed is the cost of a help article that describes buying
-- something outside the app. Before the letter, "contact us with the
-- email address you paid with" was ordinary support copy. After it, on a
-- build submitted days later, it is a description of an external
-- purchase flow in a screen a reviewer will certainly open, from a
-- developer Apple has just told is not a reader app.
--
-- Two defences, deliberately different in kind:
--
--   1. STRUCTURAL, in the app: the whole 'membership' category is hidden
--      on iOS. It is a rule about a category rather than about a row, so
--      an admin writing a new membership article cannot forget it.
--
--   2. EDITORIAL, this column: for anything else that should not appear
--      on iOS. Same mechanism, and same reasoning, as
--      app_popups.hide_on_ios — the judgement belongs to whoever wrote
--      the text.
--
-- Defaults to false so nothing changes for existing articles beyond the
-- membership rows set below.

alter table public.faqs
  add column if not exists hide_on_ios boolean not null default false;

comment on column public.faqs.hide_on_ios is
  'Withhold this article from iOS. The whole membership category is '
  'already hidden there structurally by the app; this is for individual '
  'articles that also should not appear. See '
  'mobile_app/lib/features/help_support/presentation/screens/'
  'help_support_screen.dart.';

-- Belt and braces alongside the app-side category rule. If the app rule
-- is ever loosened, these rows stay hidden on their own.
update public.faqs
   set hide_on_ios = true
 where category = 'membership';

-- The account-deletion article mentioned refunds, which is a purchase
-- concept in an article that has nothing to do with buying. Reworded for
-- both platforms rather than hidden on one: the point it needs to make is
-- that deletion is irreversible and that questions should be raised
-- first, and that survives without the word.
update public.faqs
   set answer =
     'Open Settings from your profile and choose "Delete my account". '
     'This removes your account, your listening history and your '
     'downloads, and it cannot be undone. Any access you currently have '
     'ends with it. If you have any questions about your account, ask us '
     'before deleting it — once it is gone we can no longer see its '
     'history.'
 where question = 'How do I delete my account?';

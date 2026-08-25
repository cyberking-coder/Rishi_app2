-- An explicit "do not show this pop-up on iOS" switch.
--
-- The iOS build ships as a reader app under App Store Guideline
-- 3.1.3(a), which requires it to contain no purchase mechanism and no
-- call to action pointing at one. Everything the app itself draws is
-- held behind kPurchaseUiEnabled. Pop-ups are the exception: their
-- title, body and button label are free text an admin types, and their
-- artwork is a file an admin uploads, both rendered verbatim.
--
-- The TEXT is handled automatically — ios_content_policy.dart inspects
-- it at display time and withholds the pop-up on iOS if it reads as
-- commerce. That check is in the app rather than only in the admin
-- because an admin warning can be dismissed, and because rows written
-- before the check existed are still in this table.
--
-- The ARTWORK cannot be handled that way. No code in this stack can
-- read the words baked into a JPEG, and the promotional creatives this
-- business produces routinely carry "Register Now" as part of the
-- image. That judgement belongs to the person who made the artwork,
-- which is what this column is for.
--
-- Defaults to false so nothing changes for existing pop-ups: the text
-- check still covers them, and turning this on is a deliberate act for
-- artwork that needs it.

alter table public.app_popups
  add column if not exists hide_on_ios boolean not null default false;

comment on column public.app_popups.hide_on_ios is
  'Withhold this pop-up from iOS regardless of its text. For artwork '
  'carrying a price or a purchase call to action, which no code can '
  'detect. Text is checked automatically by the app — see '
  'mobile_app/lib/core/config/ios_content_policy.dart.';

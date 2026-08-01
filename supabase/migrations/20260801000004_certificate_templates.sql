-- Admin-designed certificate artwork, with the recipient's name printed
-- onto it.
--
-- The app previously drew the certificate itself. That guarantees a
-- consistent result but gives the admin no say in how it looks, and this
-- is a branded artefact people share — the design has to be theirs.
--
-- So: they upload finished artwork, and the only thing the system adds
-- is the name. Position is stored as PERCENTAGES of the image, not
-- pixels, because the same template has to land correctly on a phone
-- screen, in a preview pane, and in whatever resolution the artwork was
-- exported at. A pixel offset would be right in exactly one of those.
--
-- Nothing here is required: a course with no template still gets the
-- natively drawn certificate, so existing courses keep working and a
-- half-configured one degrades to something presentable rather than to
-- a broken image.

alter table public.courses
  add column if not exists certificate_template_url text,
  -- Vertical position of the name's baseline, 0 = top, 100 = bottom.
  add column if not exists certificate_name_top numeric not null default 52
    check (certificate_name_top between 0 and 100),
  -- Horizontal centre of the name. Most certificate designs centre it,
  -- but a design with the name in a lower-left panel needs this.
  add column if not exists certificate_name_left numeric not null default 50
    check (certificate_name_left between 0 and 100),
  -- Font size as a percentage of the image's WIDTH, so the name scales
  -- with the artwork instead of being sized for one screen.
  add column if not exists certificate_name_size numeric not null default 7
    check (certificate_name_size between 1 and 40),
  add column if not exists certificate_name_color text not null default '#1A1A1A';

comment on column public.courses.certificate_template_url is
  'Admin-uploaded certificate artwork. The app prints the recipient name '
  'onto it at the configured position. Null = use the app''s own drawn '
  'certificate design.';

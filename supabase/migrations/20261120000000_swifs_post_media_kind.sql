-- Swifs: allow the photo kind the app sends ('image').
-- Safe to run more than once. Run in Supabase Dashboard -> SQL Editor.
-- The error was: new row for relation "post_media" violates check constraint
-- "post_media_kind_check". This replaces that rule with one that also accepts
-- 'image'. NOT VALID means existing rows are not re-checked.

alter table public.post_media drop constraint if exists post_media_kind_check;

alter table public.post_media
  add constraint post_media_kind_check
  check (kind in ('image', 'photo', 'gif', 'video'))
  not valid;

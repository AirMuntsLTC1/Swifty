-- Swifs: settings switches save to user_settings.
-- Safe to run more than once. Run in Supabase Dashboard -> SQL Editor.
-- user_settings already has RLS for select/insert/update of your own row
-- and its primary key is user_id, which the app upserts on.

alter table public.user_settings
  add column if not exists read_receipts boolean not null default true,
  add column if not exists sensitive_media_display boolean not null default false,
  add column if not exists sensitive_media_mark boolean not null default false,
  add column if not exists live_video boolean not null default true,
  add column if not exists push_notifications boolean not null default true;

-- Make sure the owner can always create and update their own settings row.
drop policy if exists swifs_user_settings_read_own on public.user_settings;
create policy swifs_user_settings_read_own on public.user_settings
  for select to authenticated using (user_id = auth.uid());

drop policy if exists swifs_user_settings_insert_own on public.user_settings;
create policy swifs_user_settings_insert_own on public.user_settings
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists swifs_user_settings_update_own on public.user_settings;
create policy swifs_user_settings_update_own on public.user_settings
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());





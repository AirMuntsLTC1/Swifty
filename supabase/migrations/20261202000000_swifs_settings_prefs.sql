-- Swifs: account settings storage.
-- Settings that already have a column keep it. Every other account setting is
-- saved in one jsonb column, so new switches do not need a new migration.
-- Safe to run more than once. Run in Supabase Dashboard -> SQL Editor.

alter table public.user_settings
  add column if not exists prefs jsonb not null default '{}'::jsonb;

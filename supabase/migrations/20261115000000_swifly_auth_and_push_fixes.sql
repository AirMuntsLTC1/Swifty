-- Swifly: schema fixes for the Supabase email-code auth function and push-notify.
-- Safe to run more than once (every statement is idempotent).
-- Run in: Supabase Dashboard -> SQL Editor.

-- 1. Table used by email-code-auth to hold hashed one-time codes.
create table if not exists public.email_login_codes (
  email          text primary key,
  code_hash      text        not null,
  purpose        text        not null check (purpose in ('signup', 'password_reset')),
  user_metadata  jsonb       not null default '{}'::jsonb,
  expires_at     timestamptz not null,
  attempts       integer     not null default 0,
  last_sent_at   timestamptz,
  created_at     timestamptz not null default now()
);

-- Only the service role (the Edge Function) may read or write codes.
-- RLS on with no policies + no grants to anon/authenticated = no client access.
alter table public.email_login_codes enable row level security;
revoke all on public.email_login_codes from anon, authenticated;

-- 2. push-notify reads notifications.actor_id, which the table did not have.
alter table public.notifications
  add column if not exists actor_id uuid references public.profiles(id) on delete set null;

create index if not exists notifications_actor_idx
  on public.notifications (actor_id);



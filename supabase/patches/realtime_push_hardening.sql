-- Swifs realtime and device-token hardening.
-- Run in Supabase Dashboard -> SQL Editor as a project owner.
-- This is safe to run repeatedly. It does not create duplicate push triggers;
-- the two Database Webhooks are configured separately in the dashboard.

-- These tables already appeared in the supplied project report's
-- supabase_realtime publication. Add them only if the publication is missing
-- one of them in the live project.
do $$
declare
  table_name text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise exception 'Publication supabase_realtime does not exist in this Supabase project';
  end if;

  foreach table_name in array array['messages', 'notifications'] loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end;
$$;

-- Preserve the user-scoped visibility the existing client subscriptions rely on.
alter table public.messages enable row level security;
alter table public.notifications enable row level security;

drop policy if exists swifs_messages_read on public.messages;
create policy swifs_messages_read on public.messages
  for select to authenticated
  using (
    sender = auth.uid()
    or recipient = auth.uid()
    or (group_id is not null and public.is_group_member(group_id))
  );

drop policy if exists swifs_notifications_read_own on public.notifications;
create policy swifs_notifications_read_own on public.notifications
  for select to authenticated
  using (user_id = auth.uid());

grant select on table public.messages, public.notifications to authenticated;
grant update on table public.messages, public.notifications to authenticated;

-- Keep the token-write path server-controlled. Never add a client INSERT policy
-- to user_devices; the app calls this SECURITY DEFINER function instead.
create or replace function public.swifly_register_push_token(
  p_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  if p_token is null or length(trim(p_token)) = 0 then
    raise exception 'FCM token is empty';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'unsupported platform';
  end if;

  insert into public.user_devices (token, user_id, platform, updated_at)
  values (trim(p_token), auth.uid(), p_platform, now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;

revoke all on function public.swifly_register_push_token(text, text) from public, anon;
grant execute on function public.swifly_register_push_token(text, text) to authenticated;





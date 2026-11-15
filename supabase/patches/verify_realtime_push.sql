-- Run after realtime_push_hardening.sql. These checks expose no FCM tokens.

-- 1) messages and notifications must both be published.
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in ('messages', 'notifications')
order by tablename;

-- 2) Confirm the expected read policies exist.
select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public'
  and tablename in ('messages', 'notifications')
order by tablename, policyname;

-- 3) Count registered devices by user/platform without showing token values.
select user_id, platform, count(*) as device_count, max(updated_at) as last_registered
from public.user_devices
group by user_id, platform
order by last_registered desc;

-- 4) Confirm the RPC functions needed by the app exist.
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in ('swifly_register_push_token', 'swifly_unread_counts')
order by routine_name;





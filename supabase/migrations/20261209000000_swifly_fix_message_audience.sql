-- Swifly: fix the "Receive message requests" setting.
-- The app saves messages_audience as 'everyone' (requests on) or 'followers'
-- (requests off). The old check constraint rejected 'followers'.
-- Order matters: drop the old constraint first, convert old values, then add
-- the new constraint. Run in Supabase Dashboard -> SQL Editor, or supabase db push.

-- 1. Remove the old constraint so the cleanup below can save 'followers'.
alter table public.user_settings
  drop constraint if exists user_settings_messages_audience_check;

-- 2. Map any other values onto the two the app uses. Restrictive values become
--    'followers' so privacy is never loosened by this change.
update public.user_settings
set messages_audience = 'followers'
where messages_audience is not null
  and messages_audience not in ('everyone', 'followers');

-- 3. Add the constraint with the allowed values.
alter table public.user_settings
  add constraint user_settings_messages_audience_check
  check (messages_audience in ('everyone', 'followers'));

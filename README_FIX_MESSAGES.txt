SWIFLY: MESSAGES FIX
====================

WHAT IT FIXES
1. "upsertUserSettings ... user_settings_messages_audience_check" when you turn
   "Receive message requests" on or off. The database rejected the value the app
   saves. The migration sets the allowed values to 'everyone' and 'followers'.
2. An empty Messages screen now shows "No messages yet" instead of a blank page.

STEPS
1. Unzip into your project folder.
2. In Termux, from the project root:
       python3 patch_messages_list.py
3. Run the migration:
       supabase db push --remote
   Or paste supabase/migrations/20261209000000_swifly_fix_message_audience.sql
   into the SQL Editor and run it.
4. Commit, push, and build.

WHY THE MESSAGES LIST IS BLANK
If you deleted conversations earlier, they are hidden for your account, so
the list is correctly empty. Messages are removed from the database only after
both people have deleted them. To check in the Supabase SQL Editor, replace
<YOUR-USER-ID> with your user id (the id from the profiles table, or
select auth.uid() after signing in):

    select count(*) as messages_you_sent_or_received
    from public.messages
    where sender = '<YOUR-USER-ID>' or recipient = '<YOUR-USER-ID>';

    select count(*) as conversations_you_hid
    from public.message_hidden
    where user_id = '<YOUR-USER-ID>';

If the first number is higher than zero and the second is the same or larger, the
conversations are only hidden for you. To show them again, run this (only messages
that still exist come back):

    delete from public.message_hidden where user_id = '<YOUR-USER-ID>';

Messages that both people deleted are gone for good and cannot be restored.

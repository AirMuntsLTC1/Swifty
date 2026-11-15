Fix: permission denied when editing profile.

Apply in Termux: no code change.
Run supabase/migrations/20261123000000_swifs_profile_grants.sql in the Supabase SQL Editor.

If it still fails, run this in the SQL Editor and send me the result:
select privilege_type, column_name from information_schema.column_privileges where table_name = 'profiles' and grantee = 'authenticated';





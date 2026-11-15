-- Swifs: signed-in users can update their own profile fields.
-- Safe to run more than once. Run in Supabase Dashboard -> SQL Editor.
-- The error "permission denied for table profiles" means the database role
-- has no privilege to write the new columns (location, date_of_birth,
-- cover_url). Row-level policies already limit each user to their own row.

grant update (display_name, bio, avatar_url, cover_url, location, date_of_birth)
  on public.profiles to authenticated;





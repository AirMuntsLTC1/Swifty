Swifs settings: switches now save to Supabase.

Apply in Termux:
  unzip -o ~/storage/downloads/swifs_settings_fix.zip -d ~/NewApp
  cd ~/NewApp && git add -A && git commit -m 'Save settings switches to Supabase' && git push

Then run supabase/migrations/20261118000000_swifs_settings_columns.sql in the Supabase SQL Editor.



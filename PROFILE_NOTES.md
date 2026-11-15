Profile edit saves everything; retweets show in feed and profile; white dialogs.

Apply in Termux:
  unzip -o ~/storage/downloads/swifs_profile_retweet_fix.zip -d ~/NewApp
  cd ~/NewApp && git add -A && git commit -m 'Profile edit, retweets in feed, white dialogs' && git push

Then run supabase/migrations/20261122000000_swifs_profile_fields.sql in the Supabase SQL Editor.





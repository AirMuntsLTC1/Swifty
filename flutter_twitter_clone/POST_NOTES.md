Fix: post with photo.

Apply in Termux:
  unzip -o ~/storage/downloads/swifs_post_fix.zip -d ~/NewApp
  cd ~/NewApp && git add -A && git commit -m 'Atomic post with photo' && git push

Then run supabase/migrations/20261119000000_swifs_create_post.sql in the Supabase SQL Editor.



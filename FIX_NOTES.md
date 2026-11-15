# Swifly feed fix: what changed and how to apply it in Termux

## Changed files (copy over your project, same paths)
1. lib/supabase/supabase_repository.dart
   - Uploads now send the real image content type (image/jpeg, image/png...).
     Before, storage saved them as text/plain, so images showed the grey "!" box.
   - Replies can store an image (comments.image_url).
2. lib/state/feedState.dart
   - createTweet no longer swallows the result; it reads the new post back with
     retries so it appears at once. Realtime adds it if the read is late.
   - The home list no longer disappears while the app is busy.
   - Replies keep their image.
3. lib/ui/page/feed/composeTweet/composeTweet.dart
   - Submit is rewritten: a failed image upload or failed save shows a message
     instead of silently doing nothing. Mention notifications can't block a post.
4. lib/widgets/tweet/widgets/tweetImage.dart
   - Tapping a post passes the post into the detail stack immediately, so the
     image/thread page no longer opens blank while it waits for the network.

## Supabase (run once, in the Supabase Dashboard -> SQL Editor)
supabase/migrations/20261117000000_swifly_feed_rls_fix.sql
- Adds comments.image_url, indexes, and explicit WITH CHECK insert policies
  for every table the app writes to, a reply-delete rule for post owners,
  realtime publication checks, and storage upload rules.
- Safe to run more than once.

## Apply in Termux
    cd ~
    unzip -o swifly_feed_fix.zip -d ~/Swifly
    cd ~/Swifly
    git add -A && git commit -m "Fix feed, replies, images and RLS"
    git push

Then run the SQL file in Supabase, then let GitHub Actions build.

## Test after install
- Post text only: it appears at the top of Home immediately.
- Post with a photo: the photo shows on Home, Profile > Media, and in the thread.
- Tap a post: the Thread page shows the post and its replies, no blank screen.
- Reply with a photo: the reply shows with its image.

## Not included / to check
- Built and checked by reading the code only; not compiled here, since there is
  no Flutter toolchain in this environment. If the build reports an error, send it.
- The FCM push-token code still uses Firebase messaging on purpose; all app data
  goes through Supabase.



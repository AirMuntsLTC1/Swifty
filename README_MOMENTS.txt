SWIFLY: MOMENTS FIXES + ADS + STORY ACTIONS
===========================================

STORY VIEWER
- Tap the right third: next story. Tap the left third: previous story.
  On the first story, tapping left closes the viewer.
- Long-press: pause. Release: continue.
- Swipe down: close. Stories also close automatically after the last one.
- The top-right X is removed. Use the gestures above to close.
- Videos play with no play, pause or volume buttons.
- Right side, like the feed and TikTok: heart (like), comment (opens the reply
  box), retweet (repost). Each shows its count.

ADS
- Feed: the first ad now appears after 3 posts, then every 6.
- Moments: a full-width ad after every 6 tiles.
- Each ad uses your active campaigns first (image, card or video), then Google
  AdMob. If neither is available, nothing is shown.
- Ads show only when there is an active campaign or AdMob is enabled.
  AdMob uses Google's TEST ads until you replace the IDs in ads_config.dart.

FILES
- supabase/migrations/20261210000000_swifly_story_engagement.sql  (run in SQL Editor)
- lib/ui/page/moments/story_viewer_page.dart   (replaces the old viewer)
- lib/ui/page/moments/story_video.dart         (new, no controls)
- lib/supabase/supabase_story_engagement.dart  (new, likes, reposts, comments)
- patch_moments.py                             (feed ad timing and Moments ads)

STEPS
1. Unzip into your project. It replaces story_viewer_page.dart.
2. Run the migration in Supabase (SQL Editor, or supabase db push --remote).
3. Run: python3 patch_moments.py
4. Commit, push, and build.

NOTES
- Retweet on a Moment is a repost count. It is saved and shown on the Moment,
  but it does not add the Moment to anyone's feed. Tell me if you want that.
- Likes here are separate from the emoji reactions bar, which still works.
- Comments are the existing story replies. The count shows only when the
  story_replies table can be read by the app.
- This was checked for structure but not compiled or run on a device here. The
  build log is the real test. Send me the first error line if it fails.

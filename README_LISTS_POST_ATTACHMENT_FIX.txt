SWIFLY — LIST ATTACHMENT FIX
============================

WHAT THIS PATCH FIXES
---------------------
1. The composer previously created a post first, then tried to attach its list
   in a separate RPC. The error was swallowed, so the post appeared successful
   even when the list link was not saved.
2. The normal feed query and list timeline query did not select posts.list_id.
3. Feed hydration did not load the corresponding list row, so the feed had no
   cover/name/member data to render.
4. The tweet widget had no list-card attachment or link to open list details.

The patch now writes the optional list link in the same database transaction
as post creation, using the existing swifly_tag_post_to_list() permission
checks. It hydrates the list card for feed posts, shows a rounded cover/name/
member/follower/privacy card, and opens the existing list detail page when
that card is tapped. The list detail page uses its existing public Join and
private Request-to-join workflow. No RLS policy has been weakened.

FILES IN THIS ZIP
-----------------
This is an OVERLAY PATCH, not a full copy of your app. It contains only the
changed Dart files, one new Supabase migration, and this guide. Your uploaded
source export does not contain the full binary assets, so keep your existing
project folder and assets.

APPLY IN TERMUX
---------------
1. Go to the existing project root (the folder containing pubspec.yaml):

   cd ~/Swifty

2. Extract this ZIP into that folder, not into a new empty folder:

   unzip -o ~/storage/downloads/swifly_lists_post_attachment_fix.zip -d .

3. Confirm the files landed in the project:

   test -f lib/ui/page/lists/list_common.dart && \
   test -f supabase/migrations/20261126000000_swifs_create_post_with_list.sql && \
   echo "Patch files are in place"

APPLY THE SUPABASE MIGRATION
----------------------------
The Flutter changes expect the new RPC signature. Apply this file to the SAME
Supabase project used by this app:

   supabase/migrations/20261126000000_swifs_create_post_with_list.sql

Safest targeted method: open Supabase Dashboard → SQL Editor, paste the full
contents of that one SQL file, and run it once.

Alternatively, run `supabase db push` from this project only when the local
migration history is already linked and in sync with the intended remote
project. Do not link or push to a different Supabase project by mistake.

BUILD / VERIFY
--------------
The exported source report and Supabase report were inspected before making
this patch. Static checks confirmed the composer → state → RPC → posts.list_id
→ feed hydration → tappable card path, and all package imports in changed Dart
files resolve inside the supplied source tree.

A Flutter/Dart SDK and live Supabase credentials were not available in the
patching environment, so a real `flutter analyze`, Android build, and live
join/request test could not be run here. After applying the SQL migration,
commit and push the patch to the repository's `main` branch to use the existing
GitHub Actions Android build workflow, or build with your configured Flutter
SDK. Test with:
- Create a post and attach one of your own lists.
- Confirm the feed shows the rounded cover, list name, member/follower counts.
- Tap the card and confirm the list detail page opens.
- From another account, tap a public card and join; tap a private card and
  confirm it shows Request to join and hides members/posts until approved.

BACKUP
------
This patch only overlays the listed files, but keep a backup of your project
before applying it. It does not include or overwrite app assets, signing keys,
Firebase configuration, Supabase secrets, or Android local.properties.

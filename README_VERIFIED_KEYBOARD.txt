SWIFLY: VERIFIED BADGE + CHAT KEYBOARD FIX
==========================================

WHAT THIS FIXES
- Real verified badge stored in Supabase (profiles.is_verified), shown everywhere a user appears:
  profile, tweets, retweets, replies, search, user lists, sidebar, chat, new message, conversation info, notifications.
- Animated blue badge: pops in, gently pulses with a glow.
- Tap the badge (anywhere) to open a 3-slide explainer sheet.
- Your account wilmeolid@gmail.com (username maximo_db) is granted the badge by the migration.
  Users cannot verify themselves: a database trigger blocks it.
- Chat composer: keyboard open/close no longer rebuilds the whole message list on every frame.

STEPS (in this order)
1. Unzip this archive INTO your project folder (the one with pubspec.yaml and lib/).
   Answer "replace" only for files you intend to replace. verified_badge.dart is new.
2. In Termux, from the project root:
       python3 patch_verified_and_keyboard.py
   It prints how many badge sites and select lists were updated. Running it twice is safe.
3. Supabase Dashboard -> SQL Editor -> paste supabase/migrations/20261205000000_swifly_verified_badge.sql -> Run.
   If it says "No auth user for wilmeolid@gmail.com yet", sign in once in the app, then run the
   bottom DO block again (or run the whole file again; it is idempotent).
4. Push / build the APK through your GitHub Actions workflow as usual.
5. Test: open the chat with someone, tap the message box, type, close the keyboard. Check your
   profile, another user viewing your profile, and a tweet of yours. Tap the badge.

NOTES
- No new packages are needed. The badge uses lucide_icons_flutter, which is already in pubspec.yaml.
- The only real way to confirm there are no framedrops is on your phone in a release/profile build.
  Run `flutter run --profile` (or check the GitHub build) and open the chat keyboard repeatedly.
- Other composers (new tweet, search box, edit profile) still use the default Flutter keyboard
  behavior. If you see framedrops there too, send me that screen's file and I will apply the same fix.

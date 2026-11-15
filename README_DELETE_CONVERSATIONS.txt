SWIFLY: DELETE CONVERSATIONS + EMPTY-CHAT PROFILE
=================================================

WHAT IT DOES
- Messages list: long-press a conversation. It slides right and gets a blue
  circle on the left. Tap other conversations to select them. Title shows
  "N selected". Back or the X exits selection mode.
- The gear icon turns into a red trash icon with a smooth spin/fade.
- Trash opens a rounded dialog: "Delete conversation?" (or "Delete N
  conversations?"), a grey Cancel button and a red Yes button.
- Empty conversation: the chat shows the other user's profile picture in the
  middle, then display name with the verified badge, username, and real
  followers / following counts.
- Fonts match the app: Mulish for body text, HelveticaNeue for the Messages
  title, same as the rest of the app.

HOW DELETE WORKS (important)
- Messages are shared between the two people, so one person cannot erase the
  other person's copy directly. Instead:
    * Deleting hides the conversation for YOU only.
    * When BOTH people have deleted it, the messages are removed from the
      database (messages, reactions and hidden rows).
- Until the other person also deletes, their copy remains. That is deliberate.
- Messages that were reported are kept, so moderation records are not lost.

STEPS (in this order)
1. Unzip this archive INTO your project folder (the one with pubspec.yaml).
   chatListPage.dart is replaced on purpose. It was rewritten in full.
2. In Termux, from the project root:
       python3 patch_delete_conversations.py
3. Supabase Dashboard -> SQL Editor -> paste
   supabase/migrations/20261206000000_swifly_delete_conversation.sql -> Run.
4. Push to GitHub and build the APK.
5. Test with two accounts: delete a chat on account A; it disappears for A.
   Delete it on account B too; the messages should be gone from the messages
   table:
       select count(*) from public.messages
       where (sender = '<A id>' and recipient = '<B id>')
          or (sender = '<B id>' and recipient = '<A id>');

NOTES
- Follower and following counts are counted from the follows table. If a
  profile has a very large audience this may be slow; say so and it can be
  switched to a count-only query.
- Check that the follows table can be read by other users (RLS). If counts show
  "–", that is the usual cause.

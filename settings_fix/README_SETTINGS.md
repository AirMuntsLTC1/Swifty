# Settings fix: install and status

## Install (in Termux, from ~/NewApp)

1. Run the migration in Supabase (SQL Editor, or `supabase db push --remote`
   after copying it to `supabase/migrations/`):
   `supabase/migrations/20261202000000_swifs_settings_prefs.sql`

2. Copy the `lib/` folder over your project's `lib/`. Same file paths, so
   existing imports keep working:

       cp -r settings_fix/lib/. ~/NewApp/lib/
       cp settings_fix/supabase/migrations/*.sql ~/NewApp/supabase/migrations/

3. Fill in `lib/helper/app_info.dart`: company website, email, help centre URL,
   and the company description. Empty values show "This link is not set yet."

4. Commit and push, then run **Build NewApp APK** on GitHub.

## Status of every settings control

**Works end to end**

- Dark mode: Off, On, or Use device setting. Dim or Lights out appearance.
- Data saver: smaller images are decoded across the app.
- Proxy: enable, host and port. Applied to network requests. Restart Swifs after changing it.
- Blocked accounts: list and unblock.
- Muted words: add and remove (saved to your account).
- Password: opens the existing email-code reset screen.
- Apps and sessions: signs you out of every other device.
- Your Swifs data: exports your profile, posts, follows, blocks and settings as JSON, shared through the share sheet.
- Log out: asks for confirmation first.
- About: Help centre, Terms, Privacy, Cookie use, Legal notices, and the AirMuntLTC company page.
- In-app browser: used for the About, company and help links.

**Saved, but the feature that uses it still needs building or a backend change**

- Protect your posts: saved. The posts security rule (`swifs_posts_read`) does not yet check it, so posts stay visible. Needs an RLS update.
- Message requests, read receipts, filter messages: saved. Messaging does not read them yet.
- Photo tagging, personalisation, precise location, live video, sensitive media: saved. The features do not read them yet.
- Notification types (likes, follows, replies, mentions, moments), email frequency: saved. The `push-notify` function and an email job must read them.
- Muted words: saved. Notifications and feed do not filter on them yet.
- Content language, country: saved.
- Image quality (Wi-Fi only / never), video quality, video autoplay, sync data and interval, reduce motion, pronounce hashtag, compose image descriptions, media previews, sound effects: saved. The app has no video player, background sync or sound effects yet.

**Removed (no feature to back them):** SMS notifications, Emoji set, Muted accounts, Search settings, and the Security row.

## Developer links

The old GitHub, LinkedIn, Twitter and Blog rows are replaced by one **AirMuntLTC** entry. It opens the company page.

## Legal text

`legalPage.dart` contains templates with [bracketed] fields. Replace them with text your lawyer approves before publishing.

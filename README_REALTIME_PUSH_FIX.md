# Swifs realtime + notification repair overlay

This is an overlay patch for the existing Swifs Flutter project. Extract it into
 the project root (the folder containing `pubspec.yaml`). It does not replace
your project, Firebase configuration, Gradle/AGP/NDK versions, or app assets.

## What I found in the uploaded source and Supabase report

- `messages` and `notifications` are already listed in the `supabase_realtime`
  publication.
- The report already contains row-level policies allowing signed-in users to
  read their own notifications and messages addressed to them (or sent by them).
- The `swifly_register_push_token` RPC and the `user_devices` table exist.
- Firebase Android configuration in the source dump targets package
  `com.swifs.swifs`, which matches the app's `applicationId`.
- The original Flutter push service did not listen to `FirebaseMessaging.onMessage`,
  so FCM messages received while Swifs was open produced no visible phone alert.
- The Android manifest did not declare `POST_NOTIFICATIONS` and did not set the
  FCM default notification channel. The push function sends to the channel
  `swifs_social_notifications`, but the Android app did not create that channel.
- The Edge Function says it is called by Supabase Database Webhooks. The supplied
  Supabase report does not include Database Webhook registrations, so their
  existence and headers cannot be confirmed from these files. The secrets list
  contains `FCM_SERVICE_ACCOUNT` and `PUSH_WEBHOOK_SECRET`, but the report hashes
  secret values; it cannot prove that the service-account JSON is valid or that
  its `project_id` matches Firebase project `swifs-b2e3c`.

## Files changed

- `lib/resource/push_notification_service.dart`: foreground FCM handling, token
  registration, notification tap stream, and native notification bridge.
- `android/app/src/main/AndroidManifest.xml` and `MainActivity.kt`: Android 13+
  notification permission and a high-importance native notification channel.
- `lib/state/chats/chatState.dart`: resilient per-account subscription, event
  handling for insert/update/delete, inbox refresh after reconnect, and read
  receipt behavior for an open chat.
- `lib/state/notificationState.dart` and `notificationPage.dart`: reconnect
  refresh, debounced updates, correct read-state behavior, and rendering for
  activity notifications without a post/list ID.
- `lib/state/badgeState.dart`: subscription diagnostics and reconnect refresh.
- `lib/ui/page/homePage.dart`: removes duplicate FCM token registration.
- `supabase/functions/push-notify/index.ts`: validated FCM service account,
  delivery diagnostics, payload identifiers, list/story notification copy, and
  safer stale-token cleanup.
- `supabase/patches/`: idempotent SQL hardening and a verification query.

## Apply the patch from Termux

Open Termux and run this from the Swifs project root. Change `~/Swifly` only if
your project folder has a different name.

```sh
cd ~/Swifly
unzip -o ~/storage/downloads/Swifly_Realtime_Notifications_Fix_Overlay.zip -d .
```

The ZIP is an overlay; it only overwrites the listed files and adds the new
files. It does not delete any of your existing source files.

## Supabase steps required for phone notifications

### 1. Run the SQL hardening script

Open `supabase/patches/realtime_push_hardening.sql`, copy its contents into
Supabase Dashboard -> SQL Editor, and run it. It ensures `messages` and
`notifications` are published, keeps the read policies user-scoped, grants the
needed table permissions, and refreshes the secure device-token RPC.

You can then run `supabase/patches/verify_realtime_push.sql`. It checks the
publication, policies, function names and device counts without displaying
FCM token values.

### 2. Deploy the push function

From the project root, using the Supabase CLI already linked to this project:

```sh
supabase functions deploy push-notify --no-verify-jwt
```

Do not put the service-role key or Firebase service-account private key in the
Flutter app, GitHub source, or this ZIP.

### 3. Verify the Edge Function secrets

In Supabase Dashboard -> Project Settings -> Edge Functions -> Secrets, verify:

- `FCM_SERVICE_ACCOUNT` is the complete Firebase service-account JSON object,
  not the SHA/hash, private key alone, or a path to a file.
- That JSON contains `client_email`, `private_key` (including its PEM header and
  footer/newlines), and `project_id`.
- `project_id` is `swifs-b2e3c`, matching the Android Firebase configuration.
- `PUSH_WEBHOOK_SECRET` is set to a long random secret.

The report only contains secret names and digests, not their contents, so this
cannot be validated offline. Do not paste any secret into chat or the app.

### 4. Create or verify BOTH Database Webhooks

In Supabase Dashboard -> Database -> Webhooks, check whether these already
exist. Do not create duplicates if they are already configured correctly.

Create/verify these two webhooks:

| Setting | Webhook A | Webhook B |
|---|---|---|
| Table | `public.notifications` | `public.messages` |
| Event | `INSERT` only | `INSERT` only |
| Method | `POST` | `POST` |
| URL | `https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/push-notify` | same URL |
| Header | `Content-Type: application/json` | same |
| Secret header | `x-webhook-secret: <same value as PUSH_WEBHOOK_SECRET>` | same |

The header name must be exactly `x-webhook-secret`. The Edge Function checks
that header against the `PUSH_WEBHOOK_SECRET` Edge Function secret. The function
is deployed with `--no-verify-jwt`; its custom header is the webhook guard.

The Supabase export supplied for this repair did not list Database Webhooks,
so this dashboard check is essential. Realtime publication and Database
Webhooks are separate mechanisms: the first updates the open app; the second
asks the Edge Function to send an FCM alert to a phone.

## Build and test

Build the APK with your existing GitHub Actions workflow; no Gradle, AGP, Kotlin,
NDK or SDK versions are changed by this overlay. Install the resulting APK and
allow Swifs notifications in Android Settings when prompted.

Test with two real accounts on two devices:

1. Keep device B on the home screen. From device A, send B a direct message. The
   message should appear in B's open chat/inbox immediately and a native Android
   notification should appear while the app is open.
2. Put B's app in the background or lock the phone, then send another message.
   FCM should show a system notification.
3. From A, follow B or create a post interaction that generates a notification.
   B's Notifications page and unread badge should update without restarting.
4. Open B's chat. The unread message count should clear as its messages are read.

Android suppresses notification delivery when the user has force-stopped the
app from system settings until the app is opened again. Also check Android
Settings -> Apps -> Swifs -> Notifications if no phone alert appears.

## What is not claimed as verified

I inspected the uploaded source dumps and created this patch, but I cannot
connect to your live Supabase project, read the un-hashed secret contents, deploy
the function, or run a two-phone FCM test from these files. The app-side fixes
are in the overlay; native push delivery still depends on the two Database
Webhooks and valid Firebase service-account credentials described above.





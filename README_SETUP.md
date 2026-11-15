# Swifly – setup and build

## 1. Connect Supabase (2 values)

Open `lib/config/supabase_config.dart` and replace:

- `YOUR-PROJECT-REF` with your project URL (`https://xxxx.supabase.co`)
- `YOUR-ANON-KEY` with your **anon / publishable** key (Supabase Dashboard → Project Settings → API)

Never put the `service_role` / secret key in the app. The Edge Function keeps it on the server.

## 2. Run the database migration

Supabase Dashboard → SQL Editor → paste and run
`supabase/migrations/20261115000000_swifly_auth_and_push_fixes.sql`.

It creates `email_login_codes` if missing, locks it down, and adds `notifications.actor_id`.

## 3. Deploy the Edge Functions

With the Supabase CLI:

```
supabase functions deploy email-code-auth --no-verify-jwt
supabase functions deploy push-notify --no-verify-jwt
```

The function source is in `supabase/functions/`. The secrets it needs (`EMAIL_CODE_PEPPER`, `GOOGLE_CLIENT_ID`, `GOOGLE_SECRET_KEY`, `GOOGLE_REFRESH_TOKEN`, `EMAIL_FROM_ADDRESS`, `FCM_SERVICE_ACCOUNT`, `PUSH_WEBHOOK_SECRET`) must already be set under Project Settings → Edge Functions → Secrets.

## 4. Add the assets folder (required for the build)

The `assets/` folder (images and the HelveticaNeue fonts) was not in the source dump. Copy your existing `assets/` folder into the project root, next to `pubspec.yaml`. Flutter will not build without the files listed in `pubspec.yaml`.

## 5. GitHub secrets for the build

In your GitHub repo go to **Settings → Secrets and variables → Actions → Repository secrets** and add:
- `SUPABASE_URL`: your project URL
- `SUPABASE_PUBLISHABLE_KEY`: your publishable (anon) key

The build reads these and passes them into the app with `--dart-define`. If either is missing, the build stops with a clear message.

## 6. Build

Builds run on GitHub Actions. Push this project to a GitHub repo and the workflow `.github/workflows/build.yml` builds an arm64 APK and uploads it as an artifact.

Local build (on a computer with Flutter 3.24+):

```
flutter pub get
flutter build apk --release --target-platform=android-arm64 --split-per-abi
```

If you see a `flutter build` usage message, an old `.github/workflows/dart.yml` still exists. Delete it. Running `unzip` overwrites files but does not delete old ones.

## What is connected now

- **Sign in** (email + password) → `email-code-auth` action `login`
- **Create account** (details → 6-digit email code → password) → `send_code`, `check_code`, `create_account`
- **Forgot password** (email → code → new password) → `send_code`, `check_code`, `reset_password`
- The app shows the sign-in screen until a Supabase session exists, then opens the home page.

## Data layer: Supabase only

Firebase is no longer used for data, auth, storage, analytics, remote config or dynamic links.
Firebase Cloud Messaging stays only to get the device push token. The `push-notify` Edge Function sends the pushes.

| Feature | Supabase |
|---|---|
| Profiles, follows | `profiles`, `follows` |
| Feed, media, likes, saves, replies | `posts`, `post_media`, `post_likes`, `post_saves`, `comments` |
| Notifications (realtime) | `notifications` |
| Direct messages (realtime) | `messages` |
| Avatar and post images | Storage buckets `avatars`, `post-media` |
| Push tokens | `user_devices` via `swifly_register_push_token` |

Data access is in `lib/supabase/supabase_repository.dart`.

Apply the migration `supabase/migrations/20261116000000_swifly_flutter_bridge.sql` in the SQL Editor after the previous one.

Known limits in this version:
- Retweets are saved as new posts (the posts table has no parent column).
- Banner images are not stored (no column for them).
- Google sign-in is not connected. Use email sign-in.
- Share links use `kShareBaseUrl` in `lib/helper/utility.dart`. Change it to your domain.
- Push taps open the notifications or chat tab. The current push payload has no post or sender id.






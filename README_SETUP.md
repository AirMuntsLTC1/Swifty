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

## 5. Build

Builds run on GitHub Actions. Push this project to a GitHub repo and the workflow `.github/workflows/build.yml` builds an arm64 APK and uploads it as an artifact.

Local build (on a computer with Flutter 3.24+):

```
flutter pub get
flutter build apk --release --target-platform=android-arm64 --split-per-abi
```

Note: the bare `flutter build` command was the cause of the earlier error. It only prints usage, so it always exits with code 1. The broken workflow `dart.yml` has been removed.

## What is connected now

- **Sign in** (email + password) → `email-code-auth` action `login`
- **Create account** (details → 6-digit email code → password) → `send_code`, `check_code`, `create_account`
- **Forgot password** (email → code → new password) → `send_code`, `check_code`, `reset_password`
- The app shows the sign-in screen until a Supabase session exists, then opens the home page.

## Still on Firebase (not migrated yet)

The rest of the app (feed, posts, chats, notifications, profiles, search) still reads from Firestore and Firebase Auth, which were not converted in this pass. After signing in with Supabase, those screens will not have data until they are moved to Supabase tables. This is the next step.

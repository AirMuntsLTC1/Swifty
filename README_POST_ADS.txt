SWIFLY: POST-STYLE ADS + EMPTY STATES
=====================================

WHAT CHANGED
1. Ads look like Swifly posts: avatar, name, verified badge, "@handle · Ad",
   the "..." menu, text, media, the reply / retweet / heart / share icons, and
   a link bar with a "Learn more" button. Applies to your own campaigns and to
   Google AdMob ads.
2. AdMob ads use a custom layout (native_post_ad.xml) registered in
   MainActivity.kt, instead of Google's generic template.
3. Messages and Notifications show their empty-state text. The text was being
   drawn invisibly, so the pages looked blank.

ABOUT THE "ADMOB NATIVE AD VALIDATOR" BOX
That box is Google's developer check. It appears only when the app shows
TEST ads (the default IDs in lib/config/ads_config.dart). "No implementation
issues found" means the ad is set up correctly. Tap Dismiss. It will not appear
with your real ad unit IDs in a release build.

ABOUT THE ACTION ICONS
The comment, retweet, heart and share icons on ads match your posts visually.
They do not do anything on ads, so people cannot like or repost an ad.

STEPS
1. Unzip into your project folder (answer y to replace files you see listed).
2. In Termux, from the project root:
       python3 patch_post_ads.py
3. Commit, push, and build the APK.

IF THE BUILD FAILS
Send me the first error line. The Kotlin file is the most likely place for a
problem, because the AdMob plugin's Android API can change between versions.
If the error mentions GoogleMobileAdsPlugin or NativeAdFactory, send the full
message.

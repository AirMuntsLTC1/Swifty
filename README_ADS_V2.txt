SWIFLY: REAL ADS (IMAGE, CARD, VIDEO + ADMOB)
=============================================

WHAT IT DOES
- Feed slot after every 6 posts. Each slot shows the first of these that exists:
  1. Your own campaign: image ad, card ad (large image + link domain) or video ad.
  2. A Google AdMob native ad (if kAdMobEnabled = true).
  3. Nothing. No placeholder ads are shown.
- Video ads play muted while at least 60% is on screen. Tap the speaker icon
  to turn sound on or off. Tapping the button opens the link and records a click.
- Impressions, clicks and hides are recorded in Supabase.

FILES IN THIS ARCHIVE
- supabase/migrations/20261208000000_swifly_ads_formats.sql   (run in SQL Editor)
- lib/config/ads_config.dart        (AdMob IDs and on/off switch)
- lib/model/ad_campaign.dart        (replaces the v1 file)
- lib/widgets/ads/ad_slot.dart      (replaces the v1 file)
- lib/widgets/ads/admob_native_slot.dart (new)
- patch_ads_v2.py                   (adds the AdMob package and manifest App ID)

STEPS
1. Unzip into your project (replaces ad_campaign.dart and ad_slot.dart).
2. In Supabase SQL Editor, run supabase/migrations/20261208000000_swifly_ads_formats.sql.
3. In Termux, from the project root: python3 patch_ads_v2.py
4. Run: flutter pub get   (or let GitHub Actions do it on the build).
5. Push to GitHub and build the APK.

ADD A REAL IN-HOUSE CAMPAIGN
Replace <angle bracket> values with a real advertiser's details. The format must be
'image', 'card' or 'video'. A video ad needs video_url.

  insert into public.ad_campaigns
    (advertiser_name, advertiser_handle, advertiser_avatar_url,
     advertiser_verified, headline, body, image_url, video_url,
     format, cta_label, cta_url, status, ends_at)
  values
    ('<Advertiser name>', '<@handle>', '<avatar https url>',
     <true or false>, '<headline>', '<body text>', '<poster or image https url>',
     <'https://video.mp4' or null>, '<image|card|video>',
     'Learn more', '<https://landing-page-url>', 'active', null);

BEFORE YOU RELEASE (important)
- Test IDs. ads_config.dart uses Google's public TEST App ID and TEST ad unit.
  Create the Swifly app in the AdMob console, create a Native advanced ad unit,
  and put both IDs in ads_config.dart. Then run patch_ads_v2.py again.
  Do not tap your own live ads: AdMob can suspend the account for that.
- Consent. In the EU, UK and other regions that require consent, you must show a
  consent form before loading ads. This version does not include that form.
  Add Google's User Messaging Platform (UMP) before a public release.
- Ad review. Google reviews native ads and will not show them until the app
  is approved. Test ads show before approval.
- minSdk. google_mobile_ads needs a minimum Android version. If the build reports
  a minSdk error, raise minSdk in android/app/build.gradle to the value the error
  names.

NOT TESTED HERE
This code was checked for structure, but it was not compiled or run on a device
in this environment. Check the GitHub Actions build log first. If a file reports
an error, send me the first error line.

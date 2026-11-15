// lib/config/ads_config.dart
//
// Ad settings. Edit these, then run patch_ads_v2.py again to update the
// Android manifest.

/// Show Google AdMob native ads in feed slots that have no in-house campaign.
const bool kAdMobEnabled = true;

/// AdMob App ID written to AndroidManifest.xml.
/// This is Google's public TEST App ID. Before you release the app, replace it
/// with your Swifly AdMob App ID from the AdMob console.
const String kAdMobAppIdAndroid = 'ca-app-pub-3940256099942544~3347511713';

/// AdMob native ad unit ID used in the feed.
/// This is Google's public TEST native ad unit. Test ads are safe to tap.
/// Before you release the app, replace it with your Swifly native ad unit ID.
const String kAdMobNativeUnitAndroid = 'ca-app-pub-3940256099942544/2247696110';

// lib/widgets/ads/admob_native_slot.dart
//
// Google AdMob native ad in a feed slot. It is drawn with the Swifly post
// layout (android/.../res/layout/native_post_ad.xml, factory "swiflyPostAd").
// Nothing is shown until Google returns an ad.
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:flutter_twitter_clone/config/ads_config.dart';

/// Must match the id registered in MainActivity.kt.
const String kAdMobPostFactoryId = 'swiflyPostAd';

class AdMobSetup {
  AdMobSetup._();
  static Future<void>? _init;

  /// Starts the Mobile Ads SDK once for the whole app.
  static Future<void> ensureInitialized() {
    return _init ??= MobileAds.instance.initialize().then((_) {});
  }
}

class AdMobNativeSlot extends StatefulWidget {
  const AdMobNativeSlot({super.key});

  @override
  State<AdMobNativeSlot> createState() => _AdMobNativeSlotState();
}

class _AdMobNativeSlotState extends State<AdMobNativeSlot> {
  NativeAd? _nativeAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AdMobSetup.ensureInitialized();
    if (!mounted) return;
    final ad = NativeAd(
      adUnitId: kAdMobNativeUnitAndroid,
      factoryId: kAdMobPostFactoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob native ad failed: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    setState(() => _nativeAd = ad);
    ad.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _nativeAd;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      height: 440,
      child: AdWidget(ad: ad),
    );
  }
}

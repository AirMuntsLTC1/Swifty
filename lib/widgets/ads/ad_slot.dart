// lib/widgets/ads/ad_slot.dart
//
// Ad positions in the home feed and Moments. Each ad is drawn like a Swifly
// post: header, text, media, action icons, and a link bar with the button.
// Each slot shows, in order:
//   1. an in-house campaign (image, card or video) if one is active, or
//   2. a Google AdMob native ad if AdMob is enabled, or
//   3. nothing.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_twitter_clone/config/ads_config.dart';
import 'package:flutter_twitter_clone/helper/open_link.dart';
import 'package:flutter_twitter_clone/model/ad_campaign.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';
import 'package:flutter_twitter_clone/ui/page/profile/widgets/circular_image.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/ads/admob_native_slot.dart';
import 'package:flutter_twitter_clone/widgets/newWidget/title_text.dart';
import 'package:flutter_twitter_clone/widgets/verified_badge.dart';

/// Every this many feed posts, one ad slot is inserted.
const int kAdEvery = 6;

/// Short-lived cache so ad slots do not call the server again on every build.
class AdsCache {
  AdsCache._();
  static final AdsCache instance = AdsCache._();

  static const Duration _ttl = Duration(minutes: 5);
  List<AdCampaign>? _ads;
  DateTime? _loadedAt;

  Future<List<AdCampaign>> load() async {
    final fresh =
        _loadedAt != null && DateTime.now().difference(_loadedAt!) < _ttl;
    if (_ads != null && fresh) return _ads!;
    _ads = await SupabaseRepository.instance.fetchActiveAds(limit: 10);
    _loadedAt = DateTime.now();
    return _ads!;
  }

  void remove(String id) {
    _ads?.removeWhere((ad) => ad.id == id);
  }
}

class AdSlot extends StatefulWidget {
  const AdSlot({super.key, required this.slotIndex});

  /// 0 for the first ad in the feed, 1 for the second, and so on.
  final int slotIndex;

  @override
  State<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends State<AdSlot> {
  AdCampaign? _ad;
  bool _useAdMob = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ads = await AdsCache.instance.load();
      if (!mounted) return;
      final inHouse =
          widget.slotIndex < ads.length ? ads[widget.slotIndex] : null;
      setState(() {
        _ad = inHouse;
        _useAdMob = inHouse == null && kAdMobEnabled;
        _loaded = true;
      });
    } catch (error) {
      debugPrint('Ads failed to load: $error');
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _onHidden() {
    setState(() {
      _ad = null;
      _useAdMob = kAdMobEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final ad = _ad;
    if (ad != null) {
      return AdCard(
        key: ValueKey('ad-${ad.id}'),
        ad: ad,
        onHidden: _onHidden,
      );
    }
    if (_useAdMob) return const AdMobNativeSlot();
    return const SizedBox.shrink();
  }
}

/// An in-house ad drawn like a post.
class AdCard extends StatefulWidget {
  const AdCard({super.key, required this.ad, required this.onHidden});

  final AdCampaign ad;
  final VoidCallback onHidden;

  @override
  State<AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<AdCard> {
  bool _impressionCounted = false;

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_impressionCounted || info.visibleFraction < 0.5) return;
    _impressionCounted = true;
    _record('impression');
  }

  Future<void> _record(String kind) async {
    try {
      await SupabaseRepository.instance.recordAdEvent(widget.ad.id, kind);
    } catch (error) {
      debugPrint('Ad $kind not recorded: $error');
    }
  }

  Future<void> _click() async {
    await _record('click');
    if (!mounted) return;
    await openLink(context, widget.ad.ctaUrl);
  }

  Future<void> _hide() async {
    await _record('hide');
    AdsCache.instance.remove(widget.ad.id);
    widget.onHidden();
  }

  void _whyThisAd() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: TitleText('Why am I seeing this ad?', fontSize: 18),
        content: Text(
          'This ad was shown by ${widget.ad.advertiserName} in Swifly. You can hide it at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _domainOf(String url) => Uri.tryParse(url)?.host ?? '';

  Widget _media(AdCampaign ad) {
    if (ad.format == 'video' && ad.videoUrl != null && ad.videoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AdVideo(url: ad.videoUrl!, posterUrl: ad.imageUrl),
      );
    }
    if (ad.imageUrl == null || ad.imageUrl!.isEmpty) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: _click,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1.91,
          child: CachedNetworkImage(
            imageUrl: ad.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColor.extraLightGrey),
            errorWidget: (_, __, ___) =>
                Container(color: AppColor.extraLightGrey),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final hasBody = ad.body != null && ad.body!.trim().isNotEmpty;
    final subtitle =
        ad.format == 'card' ? _domainOf(ad.ctaUrl) : ad.advertiserHandle;

    return VisibilityDetector(
      key: Key('ad-visibility-${ad.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header, like a post: avatar, name, handle and "Ad" in place of time.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircularImage(path: ad.advertiserAvatarUrl, height: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: TitleText(
                                ad.advertiserName,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (ad.advertiserVerified) ...[
                              const SizedBox(width: 4),
                              const VerifiedBadge(size: 14),
                            ],
                          ],
                        ),
                        Text(
                          '${ad.advertiserHandle} · Ad',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColor.darkGrey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz,
                        color: AppColor.darkGrey),
                    onSelected: (value) {
                      if (value == 'hide') _hide();
                      if (value == 'why') _whyThisAd();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'hide', child: Text('Hide ad')),
                      PopupMenuItem(
                          value: 'why', child: Text('Why am I seeing this?')),
                    ],
                  ),
                ],
              ),
            ),
            if (hasBody)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Text(
                  ad.body!,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                ),
              ),
            if (!hasBody) const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _media(ad),
            ),
            // Action icons, same icons and spacing as the post row.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Icon(LucideIcons.messageCircle,
                      size: 20, color: AppColor.darkGrey),
                  Icon(LucideIcons.repeat2,
                      size: 20, color: AppColor.darkGrey),
                  Icon(LucideIcons.heart, size: 20, color: AppColor.darkGrey),
                  Icon(LucideIcons.share2, size: 20, color: AppColor.darkGrey),
                ],
              ),
            ),
            AdCtaBar(
              ad: ad,
              subtitle: subtitle,
              onPressed: _click,
            ),
          ],
        ),
      ),
    );
  }
}

/// Plays a video ad muted, only while at least 60% of it is on screen.
/// Tap the speaker icon to turn sound on or off.
class AdVideo extends StatefulWidget {
  const AdVideo({super.key, required this.url, this.posterUrl});

  final String url;
  final String? posterUrl;

  @override
  State<AdVideo> createState() => _AdVideoState();
}

class _AdVideoState extends State<AdVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    controller
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((Object error) {
        debugPrint('Ad video failed: $error');
      });
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final controller = _controller;
    if (controller == null || !_ready) return;
    if (info.visibleFraction >= 0.6) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  void _toggleSound() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _muted = !_muted;
      controller.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return VisibilityDetector(
      key: Key('ad-video-${widget.url}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.posterUrl != null && widget.posterUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.posterUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.black),
                errorWidget: (_, __, ___) => Container(color: Colors.black),
              )
            else
              Container(color: Colors.black),
            if (_ready && controller != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            Positioned(
              right: 8,
              bottom: 8,
              child: GestureDetector(
                onTap: _toggleSound,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Headline, subtitle and call-to-action button at the bottom of an ad.
class AdCtaBar extends StatelessWidget {
  const AdCtaBar({
    super.key,
    required this.ad,
    required this.subtitle,
    required this.onPressed,
  });

  final AdCampaign ad;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColor.extraExtraLightGrey,
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TitleText(
                  ad.headline,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: AppColor.darkGrey),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: onPressed,
            child: Text(ad.ctaLabel,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

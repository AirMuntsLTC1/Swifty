// lib/widgets/ads/ad_slot.dart
//
// One ad position in the home feed. Shows the ad at its position if an active
// campaign exists; otherwise shows nothing (no placeholder ads).
import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/model/ad_campaign.dart';
import 'package:flutter_twitter_clone/supabase/supabase_ads.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';
import 'package:flutter_twitter_clone/helper/open_link.dart';
import 'package:flutter_twitter_clone/ui/page/profile/widgets/circular_image.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/newWidget/title_text.dart';
import 'package:flutter_twitter_clone/widgets/verified_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Every this many feed posts, one ad slot is inserted.
const int kAdEvery = 6;

/// Short-lived cache so each ad slot does not call the server again.
class AdsCache {
  AdsCache._();
  static final AdsCache instance = AdsCache._();

  static const Duration _ttl = Duration(minutes: 5);
  List<AdCampaign>? _ads;
  DateTime? _loadedAt;

  Future<List<AdCampaign>> load() async {
    final fresh = _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < _ttl;
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ads = await AdsCache.instance.load();
      if (!mounted) return;
      // One real campaign per slot, never repeated, so a single ad does not
      // fill the whole feed.
      setState(() {
        _ad = widget.slotIndex < ads.length ? ads[widget.slotIndex] : null;
      });
    } catch (error) {
      debugPrint('Ads failed to load: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return AdCard(
      key: ValueKey('ad-${ad.id}'),
      ad: ad,
      onHidden: () => setState(() => _ad = null),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final hasBody = ad.body != null && ad.body!.trim().isNotEmpty;
    final hasImage = ad.imageUrl != null && ad.imageUrl!.isNotEmpty;
    return VisibilityDetector(
      key: Key('ad-visibility-${ad.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      Row(
                        children: [
                          const Text(
                            'Ad',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColor.darkGrey,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('·',
                              style: TextStyle(color: AppColor.darkGrey)),
                          const SizedBox(width: 4),
                          const Icon(Icons.public,
                              size: 14, color: AppColor.darkGrey),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: AppColor.darkGrey),
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
                IconButton(
                  tooltip: 'Hide ad',
                  icon: const Icon(LucideIcons.x, color: AppColor.darkGrey),
                  onPressed: _hide,
                ),
              ],
            ),
            if (hasBody) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  ad.body!,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
            ],
            if (hasImage) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _click,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: AspectRatio(
                    aspectRatio: 1.91,
                    child: CachedNetworkImage(
                      imageUrl: ad.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColor.extraLightGrey),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColor.extraLightGrey),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
          ),
          if (ad.ctaUrl.isNotEmpty)
            AdCtaBar(ad: ad, onPressed: _click),
          ],
        ),
      ),
    );
  }
}

/// Headline and call-to-action button under the ad image.
class AdCtaBar extends StatelessWidget {
  const AdCtaBar({super.key, required this.ad, required this.onPressed});

  final AdCampaign ad;
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
                Text(
                  ad.advertiserHandle,
                  style: const TextStyle(fontSize: 13, color: AppColor.darkGrey),
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

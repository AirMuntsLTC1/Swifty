// lib/ui/page/moments/moments_widgets.dart
//
// Small widgets shared by the Moments screens. Mulish type and Lucide icons,
// matching the rest of the app.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/moment_models.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/cache_image.dart';
import 'package:flutter_twitter_clone/widgets/video/post_video_player.dart';
import 'package:flutter_twitter_clone/widgets/video/video_poster.dart';

const Color kMomentBorder = Color(0xffEFF3F4);
const Color kMomentMuted = Color(0xff536471);
const Color kMomentInk = Color(0xff0F1419);

TextStyle momentTitle({double size = 16, Color color = kMomentInk}) {
  return GoogleFonts.mulish(
      fontSize: size, fontWeight: FontWeight.w800, color: color);
}

TextStyle momentMuted({double size = 13, Color color = kMomentMuted}) {
  return GoogleFonts.mulish(
      fontSize: size, fontWeight: FontWeight.w600, color: color);
}

/// Short relative time: "now", "12m", "3h", "2d".
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  return '${diff.inDays}d';
}

String compactMomentCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
  return '$n';
}

Color momentColorFor(String seed) {
  return Color(kMomentBgColors[seed.hashCode.abs() % kMomentBgColors.length]);
}

/// Thin bars across the top of a story-style viewer. Completed bars are full,
/// the current bar follows [progress], later bars are empty.
class MomentProgressBars extends StatelessWidget {
  const MomentProgressBars({
    super.key,
    required this.count,
    required this.index,
    required this.progress,
  });

  final int count;
  final int index;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedBuilder(
                animation: progress,
                builder: (context, child) {
                  final value =
                      i < index ? 1.0 : (i == index ? progress.value : 0.0);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      backgroundColor: Colors.white30,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Red "LIVE" pill used on capsules.
class MomentLiveBadge extends StatelessWidget {
  const MomentLiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: TwitterColor.ceriseRed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: GoogleFonts.mulish(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// A circular avatar in the story row. A blue gradient ring means unseen
/// stories, a grey ring means everything has been seen.
class StoryRing extends StatelessWidget {
  const StoryRing({
    super.key,
    required this.label,
    required this.avatar,
    required this.highlighted,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String? avatar;
  final bool highlighted;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: highlighted
                        ? const LinearGradient(
                            colors: [AppColor.primary, Color(0xff66B3FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: highlighted ? null : kMomentBorder,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: CacheImage(path: avatar, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                if (badge != null) Positioned(right: 0, bottom: 0, child: badge!),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: momentMuted(size: 12, color: kMomentInk),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4:5 capsule card for a trending tag, with a LIVE badge.
class CapsuleCard extends StatelessWidget {
  const CapsuleCard({super.key, required this.capsule, required this.onTap});

  final MomentCapsule capsule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The first post with a picture (a video counts with its thumbnail).
    final posters = capsule.posts.where((p) {
      final poster = p.posterUrl;
      return poster != null && poster.isNotEmpty;
    });
    final String? cover = posters.isEmpty ? null : posters.first.posterUrl;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 200,
        height: 260,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              cover == null
                  ? Container(color: momentColorFor(capsule.tag))
                  : CacheImage(path: cover, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
              const Positioned(top: 12, left: 12, child: MomentLiveBadge()),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#${capsule.tag}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: momentTitle(size: 18, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${compactMomentCount(capsule.uses)} posts · Tap to watch',
                      style: momentMuted(size: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square-ish tile in the explore grid: the photo, or the text on a color.
class MomentTile extends StatelessWidget {
  const MomentTile({super.key, required this.post, required this.onTap});

  final FeedModel post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final poster = post.posterUrl;
    final hasPoster = poster != null && poster.isNotEmpty;
    final isVideo = post.mediaKind == 'video';
    final text = (post.description ?? '').trim();

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: hasPoster
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CacheImage(path: poster, fit: BoxFit.cover),
                  if (isVideo)
                    const Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white70, size: 44),
                    ),
                ],
              )
            : isVideo
                ? VideoPoster(videoUrl: post.imagePath)
                : Container(
                    color: momentColorFor(post.key ?? text),
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        text,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: momentTitle(size: 14, color: Colors.white),
                      ),
                    ),
                  ),
      ),
    );
  }
}

/// "For you" / "Trending" style pill. Selected pills are filled blue.
class MomentFilterPill extends StatelessWidget {
  const MomentFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColor.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColor.primary : kMomentBorder,
          ),
        ),
        child: Text(
          label,
          style: momentTitle(
            size: 14,
            color: selected ? Colors.white : kMomentInk,
          ),
        ),
      ),
    );
  }
}

/// Emojis that float up from the bottom of the screen when called.
/// Create one with a GlobalKey and call `key.currentState?.burst('🔥')`.
class EmojiBurstLayer extends StatefulWidget {
  const EmojiBurstLayer({super.key});

  @override
  State<EmojiBurstLayer> createState() => EmojiBurstLayerState();
}

class EmojiBurstLayerState extends State<EmojiBurstLayer> {
  final Random _random = Random();
  final List<_Burst> _bursts = <_Burst>[];
  int _nextId = 0;

  void burst(String emoji) {
    if (!mounted) return;
    setState(() {
      _bursts.add(
        _Burst(_nextId++, emoji, _random.nextDouble() * 120 - 60),
      );
    });
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _bursts.removeWhere((b) => b.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return IgnorePointer(
      child: Stack(
        children: [
          for (final b in _bursts)
            _FloatingEmoji(
              key: ValueKey<int>(b.id),
              emoji: b.emoji,
              drift: b.drift,
              left: width / 2 - 22,
              onDone: () => _remove(b.id),
            ),
        ],
      ),
    );
  }
}

class _Burst {
  _Burst(this.id, this.emoji, this.drift);

  final int id;
  final String emoji;
  final double drift;
}

class _FloatingEmoji extends StatefulWidget {
  const _FloatingEmoji({
    super.key,
    required this.emoji,
    required this.drift,
    required this.left,
    required this.onDone,
  });

  final String emoji;
  final double drift;
  final double left;
  final VoidCallback onDone;

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 130,
      left: widget.left,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_controller.value);
          return Opacity(
            opacity: (1 - _controller.value).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(widget.drift * t, -240 * t),
              child: Transform.scale(
                scale: 0.7 + 0.6 * t,
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 34),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}





/// Explore-grid cover for a video post: a dark tile with a play badge.
class _VideoTileCover extends StatelessWidget {
  const _VideoTileCover();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color(0xFF2A3440)),
        Center(
          child: Icon(Icons.play_circle_fill_rounded,
              color: Colors.white70, size: 44),
        ),
      ],
    );
  }
}

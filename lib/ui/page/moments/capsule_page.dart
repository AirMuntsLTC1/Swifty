// lib/ui/page/moments/capsule_page.dart
//
// Plays a list of posts full-screen, like a story deck. Each post stays for
// about 7 seconds. Tap right or left to skip, long-press to pause, swipe to
// browse. Used by trending capsules (live: true) and by the explore grid.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_twitter_clone/helper/customRoute.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/ui/page/moments/moments_widgets.dart';
import 'package:flutter_twitter_clone/widgets/cache_image.dart';
import 'package:flutter_twitter_clone/widgets/video/post_video_player.dart';

class CapsulePage extends StatefulWidget {
  const CapsulePage({
    super.key,
    required this.title,
    required this.posts,
    this.initialIndex = 0,
    this.live = false,
  });

  final String title;
  final List<FeedModel> posts;
  final int initialIndex;
  final bool live;

  static Route<void> getRoute({
    required String title,
    required List<FeedModel> posts,
    int initialIndex = 0,
    bool live = false,
  }) {
    return CustomRoute<void>(
      builder: (_) => CapsulePage(
        title: title,
        posts: posts,
        initialIndex: initialIndex,
        live: live,
      ),
      settings: const RouteSettings(name: 'MomentCapsule'),
    );
  }

  @override
  State<CapsulePage> createState() => _CapsulePageState();
}

class _CapsulePageState extends State<CapsulePage>
    with SingleTickerProviderStateMixin {
  static const Duration _postLength = Duration(seconds: 7);

  late final PageController _pages;
  late final AnimationController _timer;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.posts.length - 1).toInt();
    _pages = PageController(initialPage: _index);
    _timer = AnimationController(vsync: this, duration: _postLength)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _go(1);
      });
    _timer.forward(from: 0);
  }

  @override
  void dispose() {
    _pages.dispose();
    _timer.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0) {
      _timer.forward(from: 0);
      return;
    }
    if (next >= widget.posts.length) {
      Navigator.of(context).maybePop();
      return;
    }
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _setHolding(bool hold) {
    if (hold) {
      _timer.stop();
    } else {
      _timer.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final width = MediaQuery.of(context).size.width;
                _go(details.localPosition.dx < width / 3 ? -1 : 1);
              },
              onLongPressStart: (_) => _setHolding(true),
              onLongPressEnd: (_) => _setHolding(false),
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.posts.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _timer.forward(from: 0);
                },
                itemBuilder: (context, i) => _PostSlide(post: widget.posts[i]),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  MomentProgressBars(
                    count: widget.posts.length,
                    index: _index,
                    progress: _timer,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (widget.live) ...[
                        const MomentLiveBadge(),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: momentTitle(size: 16, color: Colors.white),
                        ),
                      ),
                      Text(
                        '${_index + 1}/${widget.posts.length}',
                        style: momentMuted(size: 13, color: Colors.white70),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One post, full-screen: its photo (or a color with the text), and the
/// author and text along the bottom.
class _PostSlide extends StatelessWidget {
  const _PostSlide({required this.post});

  final FeedModel post;

  @override
  Widget build(BuildContext context) {
    final image = post.imagePath;
    final hasImage = image != null && image.isNotEmpty;
    final text = (post.description ?? '').trim();

    final isVideo = post.mediaKind == 'video';

    return Stack(
      fit: StackFit.expand,
      children: [
        !hasImage
            ? Container(color: momentColorFor(post.key ?? text))
            : isVideo
                ? Center(
                    child: PostVideoPlayer(
                      url: image,
                      thumbnailUrl: post.thumbnailUrl,
                      aspectRatio: 9 / 16,
                      borderRadius: 0,
                      autoPlayWhenVisible: true,
                    ),
                  )
                : CacheImage(path: image, fit: BoxFit.cover),
        if (hasImage)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
              ),
            ),
          ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CacheImage(
                        path: post.user?.profilePic,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      post.user?.displayName ?? 'Swifs user',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: momentTitle(size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  text,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: momentTitle(
                    size: hasImage ? 17 : 26,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}





// lib/widgets/video/post_video_player.dart
//
// Inline video for the feed, threads, profiles, stories and the composer.
//
// - The thumbnail (stored with the post) is shown at once, so there is never
//   a black box. Once the video starts playing, the picture is the video.
// - In the feed and threads it plays by itself, muted, while at least 60% of
//   it is on screen. When it scrolls away it pauses, and the player is
//   released so long feeds do not keep many decoders alive.
// - Only one video plays at a time: starting one pauses the other.
// - Tapping opens the thread when [onTap] is given (feed). Inside a thread
//   (no [onTap]) a tap pauses or plays. The speaker button mutes or unmutes.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/cache_image.dart';

class PostVideoPlayer extends StatefulWidget {
  const PostVideoPlayer({
    super.key,
    this.url,
    this.file,
    this.thumbnailUrl,
    this.borderRadius = 20,
    this.aspectRatio = 4 / 3,
    this.fit = BoxFit.cover,
    this.autoPlayWhenVisible = false,
    this.startMuted = true,
    this.onTap,
  }) : assert(url != null || file != null, 'Pass a url or a file');

  /// Public storage URL of the video.
  final String? url;

  /// A local file, used for the preview before posting.
  final File? file;

  /// Still image shown until the video starts. Null shows a plain placeholder.
  final String? thumbnailUrl;
  final double borderRadius;

  /// Frame shape. The feed uses 4:3, stories use the full screen.
  final double aspectRatio;
  final BoxFit fit;

  /// Play by itself while mostly on screen, and pause when scrolled away.
  final bool autoPlayWhenVisible;
  final bool startMuted;

  /// If set, a tap calls this instead of play/pause (used to open the thread).
  final VoidCallback? onTap;

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  /// The video that is currently playing, anywhere on screen.
  static _PostVideoPlayerState? _active;

  final Key _visibilityKey = UniqueKey();
  VideoPlayerController? _controller;
  bool _initialising = false;
  bool _failed = false;
  bool _muted = true;
  double _visibleFraction = 0;

  @override
  void initState() {
    super.initState();
    _muted = widget.startMuted;
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    _releaseController();
    super.dispose();
  }

  bool get _ready => _controller?.value.isInitialized ?? false;

  bool get _playing => _controller?.value.isPlaying ?? false;

  /// True once the first frame is showing, so the picture covers the thumbnail.
  bool get _started =>
      _ready && (_playing || _controller!.value.position > Duration.zero);

  // ---------------------------------------------------------------------------
  // Loading and releasing the player
  // ---------------------------------------------------------------------------

  Future<bool> _initialise() async {
    if (_initialising) return false;
    _initialising = true;
    _failed = false;
    if (mounted) setState(() {});

    final c = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(_muted ? 0 : 1);
      if (!mounted) {
        await c.dispose();
        _initialising = false;
        return false;
      }
      c.addListener(_onControllerTick);
      _controller = c;
      _initialising = false;
      setState(() {});
      return true;
    } catch (error) {
      debugPrint('Video failed to load: $error');
      await c.dispose();
      _initialising = false;
      if (mounted) setState(() => _failed = true);
      return false;
    }
  }

  /// Frees the decoder. The thumbnail shows again until the next play.
  void _releaseController() {
    final c = _controller;
    _controller = null;
    if (_active == this) _active = null;
    if (c != null) {
      c.removeListener(_onControllerTick);
      c.dispose();
    }
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Play, pause and visibility
  // ---------------------------------------------------------------------------

  Future<void> _play() async {
    if (_initialising) return;
    if (!_ready) {
      final ok = await _initialise();
      if (!ok || !mounted) return;
      // Scrolled away while it was loading: do not start it now.
      if (widget.autoPlayWhenVisible && _visibleFraction < 0.1) {
        _releaseController();
        return;
      }
    }
    final c = _controller;
    if (c == null || c.value.isPlaying) return;
    if (_active != null && _active != this) _active!._pauseFromOther();
    _active = this;
    await c.play();
  }

  void _pause() {
    _controller?.pause();
    if (_active == this) _active = null;
  }

  void _pauseFromOther() {
    _controller?.pause();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    _visibleFraction = info.visibleFraction;
    if (!mounted) return;
    if (_visibleFraction >= 0.6) {
      _play();
    } else if (_visibleFraction < 0.1) {
      _pause();
      if (_visibleFraction == 0) _releaseController();
    }
  }

  void _onTap() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    if (_playing) {
      _pause();
    } else {
      _play();
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller?.setVolume(_muted ? 0 : 1);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final frame = AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: ColoredBox(
            color: const Color(0xFF1B1F23),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _poster(),
                if (c != null && _started) _videoLayer(c),
                _centerIcon(),
                if (c != null && _ready) _controls(c),
              ],
            ),
          ),
        ),
      ),
    );

    if (!widget.autoPlayWhenVisible) return frame;
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: frame,
    );
  }

  /// The picture shown before the video starts. Never black.
  Widget _poster() {
    if (_started) return const SizedBox.shrink();
    final thumb = widget.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) {
      return CacheImage(path: thumb, fit: widget.fit);
    }
    return const SizedBox.shrink();
  }

  Widget _videoLayer(VideoPlayerController c) {
    final size = c.value.size;
    return FittedBox(
      fit: widget.fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(c),
      ),
    );
  }

  Widget _centerIcon() {
    if (_initialising) {
      return const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
        ),
      );
    }
    if (_failed) {
      return const Center(
        child: _CenterButton(
          icon: Icons.refresh_rounded,
          label: 'Could not play. Tap to retry',
        ),
      );
    }
    if (_playing) return const SizedBox.shrink();
    return const Center(child: _CenterButton(icon: Icons.play_arrow_rounded));
  }

  Widget _controls(VideoPlayerController c) {
    return Stack(
      children: [
        Positioned(
          right: 8,
          bottom: 14,
          child: GestureDetector(
            onTap: _toggleMute,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: VideoProgressIndicator(
            c,
            allowScrubbing: true,
            padding: EdgeInsets.zero,
            colors: VideoProgressColors(
              playedColor: AppColor.primary,
              bufferedColor: Colors.white30,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
      ],
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 34, color: Colors.white),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

// lib/widgets/video/post_video_player.dart
//
// Inline video for the feed, threads, profiles, stories and the composer.
//
// - The picture is the stored thumbnail (or a poster made from the video),
//   shown until the video starts. Never a black box.
// - In the feed and threads it plays by itself, muted, while at least 60% of
//   it is on screen. When it scrolls away it pauses and the decoder is freed.
// - Only one video plays at a time.
// - [onTap] opens the thread (feed). Without it, a tap pauses or plays.
// - Stories use [looping] false, [maxPlayback] and the position callbacks, so
//   the story bars follow the video's own length.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/video/video_poster.dart';

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
    this.looping = true,
    this.paused = false,
    this.maxPlayback,
    this.onTap,
    this.onDuration,
    this.onPosition,
    this.onError,
  }) : assert(url != null || file != null, 'Pass a url or a file');

  final String? url;
  final File? file;
  final String? thumbnailUrl;
  final double borderRadius;
  final double aspectRatio;
  final BoxFit fit;

  /// Play by itself while mostly on screen, and pause when scrolled away.
  final bool autoPlayWhenVisible;
  final bool startMuted;

  /// Repeat the video. Stories turn this off, so the video ends once.
  final bool looping;

  /// Pause from outside (for example while a story is held).
  final bool paused;

  /// Stop playing at this position (stories use 59 seconds).
  final Duration? maxPlayback;

  /// If set, a tap calls this instead of play/pause (used to open the thread).
  final VoidCallback? onTap;

  /// Called once when the video's length is known.
  final ValueChanged<Duration>? onDuration;

  /// Called as the video plays. At the end it is called with the end position.
  final ValueChanged<Duration>? onPosition;

  /// Called if the video cannot be loaded.
  final VoidCallback? onError;

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
  void didUpdateWidget(covariant PostVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged = oldWidget.url != widget.url ||
        oldWidget.file?.path != widget.file?.path;
    if (sourceChanged) {
      _releaseController();
      _failed = false;
      if (widget.autoPlayWhenVisible && _visibleFraction >= 0.6) _play();
      return;
    }
    if (oldWidget.paused != widget.paused) {
      if (widget.paused) {
        _pause();
      } else if (widget.autoPlayWhenVisible && _visibleFraction >= 0.6) {
        _play();
      }
    }
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    _releaseController();
    super.dispose();
  }

  bool get _ready => _controller?.value.isInitialized ?? false;

  bool get _playing => _controller?.value.isPlaying ?? false;

  /// True once playback has started, so the video covers the poster.
  bool get _started =>
      _ready && (_playing || _controller!.value.position > Duration.zero);

  /// The end of playback: the video's length, or [maxPlayback] if shorter.
  Duration _playbackEnd(VideoPlayerController c) {
    final length = c.value.duration;
    final max = widget.maxPlayback;
    return (max != null && max < length) ? max : length;
  }

  // ---------------------------------------------------------------------------
  // Loading and releasing the player
  // ---------------------------------------------------------------------------

  Future<bool> _initialise() async {
    if (_initialising) return false;
    _initialising = true;
    _failed = false;
    if (mounted) setState(() {});

    // mixWithOthers: this player does not take exclusive audio focus, so
    // another player on screen cannot silence it.
    final options = VideoPlayerOptions(mixWithOthers: true);
    final c = widget.file != null
        ? VideoPlayerController.file(widget.file!, videoPlayerOptions: options)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!),
            videoPlayerOptions: options);
    try {
      await c.initialize();
      await c.setLooping(widget.looping);
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
      widget.onDuration?.call(c.value.duration);
      return true;
    } catch (error) {
      debugPrint('Video failed to load: $error');
      await c.dispose();
      _initialising = false;
      if (mounted) setState(() => _failed = true);
      widget.onError?.call();
      return false;
    }
  }

  /// Frees the decoder. The poster shows again until the next play.
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
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      final end = _playbackEnd(c);
      final position = c.value.position;
      // Stop at the cap (for example 59 seconds in a story).
      if (c.value.isPlaying && position >= end) {
        c.pause();
      }
      final atEnd = position >= end - const Duration(milliseconds: 150);
      widget.onPosition?.call(atEnd ? end : position);
    }
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
    if (c.value.position >= _playbackEnd(c)) {
      await c.seekTo(Duration.zero);
    }
    if (_active != null && _active != this) _active!._pauseFromOther();
    _active = this;
    await c.setVolume(_muted ? 0 : 1);
    await c.play();
    await c.setVolume(_muted ? 0 : 1);
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
      if (!widget.paused) _play();
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

  /// Speaker button. Changes the volume at once, and the icon follows it.
  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _controller?.setVolume(_muted ? 0 : 1);
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
            color: const Color(0xFF2A3440),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!_started) _poster(),
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

  Widget _poster() {
    return VideoPoster(
      thumbnailUrl: widget.thumbnailUrl,
      videoUrl: widget.url,
      videoFile: widget.file,
      fit: widget.fit,
    );
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

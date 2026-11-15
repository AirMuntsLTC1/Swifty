// lib/widgets/video/post_video_player.dart
//
// Inline video used in the feed, on profiles, in the composer preview and in
// stories. The player loads on the first tap, so a long feed does not start
// many decoders at once. Tap the video to play or pause, use the speaker
// button to mute, and drag the bar at the bottom to seek.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:flutter_twitter_clone/ui/theme/theme.dart';

class PostVideoPlayer extends StatefulWidget {
  const PostVideoPlayer({
    super.key,
    this.url,
    this.file,
    this.borderRadius = 20,
    this.fit = BoxFit.cover,
    this.aspectRatio = 4 / 3,
    this.autoPlay = false,
    this.startMuted = true,
  }) : assert(url != null || file != null, 'Pass a url or a file');

  /// Public storage URL of the video.
  final String? url;

  /// A local file, used for the preview before posting.
  final File? file;
  final double borderRadius;
  final BoxFit fit;

  /// Frame shape. Matches the 4:3 image frame used in the feed.
  final double aspectRatio;

  /// Start playing as soon as the video is ready (used by the story viewer).
  final bool autoPlay;
  final bool startMuted;

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;
  late bool _muted = widget.startMuted;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) _load();
  }

  @override
  void didUpdateWidget(covariant PostVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The story viewer reuses this widget for the next story: start over.
    if (oldWidget.url != widget.url || oldWidget.file?.path != widget.file?.path) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      if (widget.autoPlay) _load();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _ready => _controller?.value.isInitialized ?? false;

  Future<void> _load() async {
    if (_loading || _ready) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final controller = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
      await controller.play();
    } catch (error) {
      debugPrint('Video failed to load: $error');
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onTap() {
    final c = _controller;
    if (c == null || !_ready) {
      _load();
      return;
    }
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null || !_ready) return;
    setState(() => _muted = !_muted);
    c.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final c = _controller;

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: radius,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_ready && c != null)
                  FittedBox(
                    fit: widget.fit,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: c.value.size.width,
                      height: c.value.size.height,
                      child: VideoPlayer(c),
                    ),
                  ),
                if (_loading)
                  const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (!_ready)
                  Center(
                    child: _CenterButton(
                      icon: _failed
                          ? Icons.refresh_rounded
                          : Icons.play_arrow_rounded,
                      label: _failed ? 'Could not play. Tap to retry' : null,
                    ),
                  )
                else if (c != null)
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: c,
                    builder: (context, value, _) => value.isPlaying
                        ? const SizedBox.shrink()
                        : const Center(
                            child: _CenterButton(
                              icon: Icons.play_arrow_rounded,
                            ),
                          ),
                  ),
                if (_ready && c != null) ...[
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
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
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
              ],
            ),
          ),
        ),
      ),
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

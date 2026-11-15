// lib/ui/page/moments/story_video.dart
//
// Video for a Moment. Plays with no controls: no play, pause or volume button.
// The viewer pauses it with [paused] (long-press or typing a reply).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class StoryVideo extends StatefulWidget {
  const StoryVideo({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.paused = false,
    required this.maxLength,
    this.onDuration,
    this.onPosition,
    this.onError,
  });

  final String url;
  final String? thumbnailUrl;
  final bool paused;

  /// The story stops here even if the video is longer.
  final Duration maxLength;
  final ValueChanged<Duration>? onDuration;

  /// Called as the video plays. At the end it is called with the end position.
  final ValueChanged<Duration>? onPosition;
  final VoidCallback? onError;

  @override
  State<StoryVideo> createState() => _StoryVideoState();
}

class _StoryVideoState extends State<StoryVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _ended = false;
  Duration _end = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
    } catch (_) {
      if (mounted) widget.onError?.call();
      return;
    }
    if (!mounted) return;
    final length = controller.value.duration;
    _end = length > widget.maxLength ? widget.maxLength : length;
    widget.onDuration?.call(_end);
    controller.setLooping(false);
    controller.addListener(_tick);
    setState(() => _ready = true);
    if (!widget.paused) controller.play();
  }

  void _tick() {
    final controller = _controller;
    if (controller == null || !mounted || _ended) return;
    final position = controller.value.position;
    if (position >= _end) {
      _ended = true;
      controller.pause();
      widget.onPosition?.call(_end);
      return;
    }
    widget.onPosition?.call(position);
  }

  @override
  void didUpdateWidget(covariant StoryVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null || !_ready || _ended) return;
    if (widget.paused != oldWidget.paused) {
      if (widget.paused) {
        controller.pause();
      } else {
        controller.play();
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_tick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final thumb = widget.thumbnailUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumb != null && thumb.isNotEmpty)
          CachedNetworkImage(
            imageUrl: thumb,
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
      ],
    );
  }
}

// lib/ui/page/moments/story_viewer_page.dart
//
// Full-screen Moment viewer.
//   - Tap right or left to skip forward or back. Long-press to pause.
//   - Progress bars across the top, one per story from the same person.
//   - Viewers: emoji reactions (with a floating burst) and a reply box.
//   - Owners: live view count, reaction counts, and live reaction bursts.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/helper/customRoute.dart';
import 'package:flutter_twitter_clone/model/moment_models.dart';
import 'package:flutter_twitter_clone/supabase/supabase_moments_repository.dart';
import 'package:flutter_twitter_clone/ui/page/moments/moments_widgets.dart';
import 'package:flutter_twitter_clone/widgets/cache_image.dart';
import 'package:flutter_twitter_clone/widgets/video/post_video_player.dart';

class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({
    super.key,
    required this.rings,
    this.initialRing = 0,
  });

  /// Everyone you can watch, in order. The viewer moves to the next person
  /// when one person's stories finish.
  final List<MomentRing> rings;
  final int initialRing;

  static Route<void> getRoute({
    required List<MomentRing> rings,
    int initialRing = 0,
  }) {
    return CustomRoute<void>(
      builder: (_) => StoryViewerPage(rings: rings, initialRing: initialRing),
      settings: const RouteSettings(name: 'MomentStoryViewer'),
    );
  }

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  static const Duration _storyLength = Duration(seconds: 6);

  final MomentsRepository _repo = MomentsRepository.instance;
  final GlobalKey<EmojiBurstLayerState> _burstKey =
      GlobalKey<EmojiBurstLayerState>();
  final TextEditingController _reply = TextEditingController();
  final FocusNode _replyFocus = FocusNode();
  late final AnimationController _progress;

  late int _ringIndex;
  int _storyIndex = 0;
  bool _holding = false;
  bool _typing = false;
  bool _sending = false;
  StoryStats? _stats;
  final Map<String, String> _sentReactions = <String, String>{};
  RealtimeChannel? _channel;
  String? _channelStoryId;

  MomentRing get _ring => widget.rings[_ringIndex];
  MomentStory get _story => _ring.stories[_storyIndex];

  @override
  void initState() {
    super.initState();
    _ringIndex = widget.initialRing.clamp(0, widget.rings.length - 1).toInt();
    _progress = AnimationController(vsync: this, duration: _storyLength)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _replyFocus.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _enterStory());
  }

  @override
  void dispose() {
    _closeChannel();
    _progress.dispose();
    _replyFocus.removeListener(_onFocusChanged);
    _replyFocus.dispose();
    _reply.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigation between stories
  // ---------------------------------------------------------------------------

  void _enterStory() {
    if (!mounted) return;
    final story = _story;
    final mine = _ring.isMine;

    _progress.forward(from: 0);
    if (!mine) {
      _repo.markViewed(story.id).catchError((_) {});
    }
    _syncChannel(story, mine);
    setState(() => _stats = null);
    if (mine) _loadStats(story.id);
  }

  void _next() {
    if (_storyIndex < _ring.stories.length - 1) {
      setState(() => _storyIndex++);
      _enterStory();
    } else if (_ringIndex < widget.rings.length - 1) {
      setState(() {
        _ringIndex++;
        _storyIndex = 0;
      });
      _enterStory();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _enterStory();
    } else if (_ringIndex > 0) {
      setState(() {
        _ringIndex--;
        _storyIndex = _ring.stories.length - 1;
      });
      _enterStory();
    } else {
      // First story of the first person: restart it.
      _progress.forward(from: 0);
    }
  }

  void _onTapUp(TapUpDetails details) {
    FocusScope.of(context).unfocus();
    final width = MediaQuery.of(context).size.width;
    if (details.localPosition.dx < width / 3) {
      _prev();
    } else {
      _next();
    }
  }

  void _setHolding(bool hold) {
    _holding = hold;
    _syncPlayback();
  }

  void _onFocusChanged() {
    _typing = _replyFocus.hasFocus;
    _syncPlayback();
  }

  /// Pause while the finger is down or the reply box is open.
  void _syncPlayback() {
    if (_holding || _typing) {
      _progress.stop();
    } else {
      _progress.forward();
    }
  }

  // ---------------------------------------------------------------------------
  // Reactions, replies, owner stats
  // ---------------------------------------------------------------------------

  void _react(String emoji) {
    final story = _story;
    setState(() => _sentReactions[story.id] = emoji);
    _burstKey.currentState?.burst(emoji);
    _repo.react(story.id, emoji).catchError((_) {});
  }

  Future<void> _sendReply(String storyId) async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.reply(storyId, text);
      _reply.clear();
      _replyFocus.unfocus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply sent')),
        );
      }
    } catch (_) {
      // Shown by the repository.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _loadStats(String storyId) async {
    try {
      final stats = await _repo.fetchStats(storyId);
      if (mounted && _story.id == storyId) setState(() => _stats = stats);
    } catch (_) {}
  }

  Future<void> _deleteStory(MomentStory story) async {
    try {
      await _repo.deleteStory(story.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {}
  }

  /// Owners get live reactions for the story on screen.
  void _syncChannel(MomentStory story, bool mine) {
    if (_channelStoryId == story.id) return;
    _closeChannel();
    if (!mine) return;
    _channelStoryId = story.id;
    _channel = _repo.subscribeReactions(story.id, (row) {
      if (!mounted || _story.id != story.id) return;
      _burstKey.currentState?.burst((row['emoji'] ?? '🔥').toString());
      _loadStats(story.id);
    });
  }

  void _closeChannel() {
    final channel = _channel;
    _channel = null;
    _channelStoryId = null;
    if (channel != null) _repo.closeChannel(channel);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ring = _ring;
    final story = _story;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _onTapUp,
              onLongPressStart: (_) => _setHolding(true),
              onLongPressEnd: (_) => _setHolding(false),
              child: _StoryBody(story: story),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  MomentProgressBars(
                    count: ring.stories.length,
                    index: _storyIndex,
                    progress: _progress,
                  ),
                  const SizedBox(height: 10),
                  _header(ring, story),
                ],
              ),
            ),
          ),
          Positioned.fill(child: EmojiBurstLayer(key: _burstKey)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: ring.isMine ? _ownerFooter(story) : _viewerFooter(story),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(MomentRing ring, MomentStory story) {
    final place = story.place == null ? '' : ' · ${story.place}';
    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CacheImage(path: ring.author.avatar, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ring.isMine ? 'Your Moment' : ring.author.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: momentTitle(size: 14, color: Colors.white),
              ),
              Text(
                '${timeAgo(story.createdAt)}$place',
                style: momentMuted(size: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _viewerFooter(MomentStory story) {
    final sent = _sentReactions[story.id];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final emoji in kMomentEmojis)
                _reactionButton(emoji, selected: sent == emoji),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _reply,
                  focusNode: _replyFocus,
                  style: momentTitle(size: 14, color: Colors.white),
                  cursorColor: Colors.white,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendReply(story.id),
                  decoration: InputDecoration(
                    hintText: 'Send a reply',
                    hintStyle: momentMuted(size: 14, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white24,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(LucideIcons.send, color: Colors.white),
                onPressed: _sending ? null : () => _sendReply(story.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ownerFooter(MomentStory story) {
    final stats = _stats;
    final reactionText = stats == null || stats.totalReactions == 0
        ? 'No reactions yet'
        : stats.reactions.entries
            .map((e) => '${e.key} ${e.value}')
            .join('   ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
      child: Row(
        children: [
          const Icon(LucideIcons.eye, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            stats == null ? '…' : '${stats.views} views',
            style: momentTitle(size: 14, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              reactionText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: momentTitle(size: 14, color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.white),
            onPressed: () => _deleteStory(story),
          ),
        ],
      ),
    );
  }

  Widget _reactionButton(String emoji, {required bool selected}) {
    return GestureDetector(
      onTap: () => _react(emoji),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? Colors.white24 : Colors.black38,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

/// The picture or text of one story. Photos keep the scale, offset and
/// rotation saved when the story was made.
class _StoryBody extends StatelessWidget {
  const _StoryBody({required this.story});

  final MomentStory story;

  @override
  Widget build(BuildContext context) {
    final url = story.mediaUrl;
    final caption = story.text;

    if (url != null && story.mediaType == 'video') {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          Center(
            child: PostVideoPlayer(
              url: url,
              aspectRatio: 9 / 16,
              borderRadius: 0,
              fit: BoxFit.cover,
              autoPlay: true,
              startMuted: false,
            ),
          ),
          if (caption != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 200,
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: momentTitle(size: 20, color: Colors.white),
              ),
            ),
        ],
      );
    }

    if (url != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(story.photoDx, story.photoDy)
              // photo_rotation is treated as degrees. Check this matches the
              // value your story editor saves.
              ..rotateZ(story.photoRotation * math.pi / 180)
              ..scale(story.photoScale),
            child: CacheImage(path: url, fit: BoxFit.cover),
          ),
          if (caption != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 200,
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: momentTitle(size: 20, color: Colors.white),
              ),
            ),
        ],
      );
    }

    return Container(
      color: Color(story.bgColor ?? kMomentBgColors.first),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: Text(
        caption ?? '',
        textAlign: TextAlign.center,
        style: momentTitle(size: 30, color: Colors.white),
      ),
    );
  }
}





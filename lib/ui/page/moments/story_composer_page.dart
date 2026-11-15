// lib/ui/page/moments/story_composer_page.dart
//
// Creates a Moment. Either a photo (gallery or camera) with an optional
// caption, or text on a colored background. Pops with `true` when posted.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_twitter_clone/helper/app_error.dart';
import 'package:flutter_twitter_clone/helper/customRoute.dart';
import 'package:flutter_twitter_clone/model/moment_models.dart';
import 'package:flutter_twitter_clone/supabase/supabase_moments_repository.dart';
import 'package:flutter_twitter_clone/ui/page/moments/moments_widgets.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/brand/swifly_brand.dart';
import 'package:flutter_twitter_clone/widgets/video/post_video_player.dart';

class StoryComposerPage extends StatefulWidget {
  const StoryComposerPage({super.key});

  static Route<bool> getRoute() {
    return CustomRoute<bool>(
      builder: (_) => const StoryComposerPage(),
      settings: const RouteSettings(name: 'MomentComposer'),
    );
  }

  @override
  State<StoryComposerPage> createState() => _StoryComposerPageState();
}

class _StoryComposerPageState extends State<StoryComposerPage> {
  static const int _maxChars = 180;

  final MomentsRepository _repo = MomentsRepository.instance;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _text = TextEditingController();

  File? _photo;
  File? _video;
  int _bgColor = kMomentBgColors.first;
  bool _posting = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _hasMedia => _photo != null || _video != null;

  bool get _canPost =>
      !_posting && (_hasMedia || _text.text.trim().isNotEmpty);

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _photo = File(picked.path);
          _video = null;
        });
      }
    } catch (error) {
      showAppError(error, where: 'Pick photo');
    }
  }

  /// Gallery only. Story videos play at most 59 seconds.
  Future<void> _pickVideo() async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: kStoryVideoMaxLength,
      );
      if (picked != null && mounted) {
        setState(() {
          _video = File(picked.path);
          _photo = null;
        });
      }
    } catch (error) {
      showAppError(error, where: 'Pick video');
    }
  }

  Future<void> _post() async {
    if (!_canPost) return;
    setState(() => _posting = true);
    try {
      await _repo.createStory(
        image: _photo,
        video: _video,
        text: _text.text,
        bgColor: _hasMedia ? null : _bgColor,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photo != null;
    final hasVideo = _video != null;
    final hasMedia = hasPhoto || hasVideo;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('New Moment', style: momentTitle(size: 18)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: _canPost ? _post : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: _canPost
                        ? AppColor.primary
                        : AppColor.lightGrey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Post',
                    style: momentTitle(size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.6),
          child: Container(height: 0.6, color: kMomentBorder),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      hasVideo
                          ? PostVideoPlayer(
                              file: _video!,
                              aspectRatio: 4 / 5,
                              borderRadius: 0,
                            )
                          : hasPhoto
                              ? Image.file(_photo!, fit: BoxFit.cover)
                              : Container(color: Color(_bgColor)),
                      if (hasMedia) Container(color: Colors.black26),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: TextField(
                            controller: _text,
                            onChanged: (_) => setState(() {}),
                            maxLines: null,
                            textAlign: TextAlign.center,
                            cursorColor: Colors.white,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(_maxChars),
                            ],
                            style: momentTitle(
                              size: hasMedia ? 20 : 26,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: hasMedia
                                  ? 'Add a caption'
                                  : 'Type something…',
                              hintStyle: momentMuted(
                                size: hasMedia ? 18 : 22,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!hasMedia)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in kMomentBgColors)
                      GestureDetector(
                        onTap: () => setState(() => _bgColor = color),
                        child: Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 6),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(color),
                            border: Border.all(
                              color: _bgColor == color
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      LucideIcons.image,
                      'Gallery',
                      () => _pick(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      Icons.videocam_outlined,
                      'Video',
                      _pickVideo,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      LucideIcons.camera,
                      'Camera',
                      () => _pick(ImageSource.camera),
                    ),
                  ),
                  if (hasMedia) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionButton(
                        LucideIcons.trash2,
                        'Remove',
                        () => setState(() {
                          _photo = null;
                          _video = null;
                        }),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Moments disappear after 24 hours. People who follow you can reply and react.',
                textAlign: TextAlign.center,
                style: momentMuted(),
              ),
            ],
          ),
          if (_posting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white70,
                child: const Center(child: SwiflyLoader()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kMomentBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColor.primary),
            const SizedBox(width: 6),
            Text(label, style: momentTitle(size: 14)),
          ],
        ),
      ),
    );
  }
}





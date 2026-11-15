// lib/helper/video_thumbnail_helper.dart
//
// Still images for videos (posters).
//
// Many videos open with a black fade-in, so the poster is taken a little way
// into the clip, not from the very first frame.
//
// - makeVideoThumbnail(file): used when a video is picked. The JPEG is
//   uploaded and its URL is stored with the post or story.
// - posterFor(url or file): used when a video has no stored thumbnail (older
//   posts). The poster is made once per session and reused.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

final Map<String, Future<File?>> _posterMemo = <String, Future<File?>>{};

/// JPEG poster for a picked video file, uploaded with the post or story.
Future<File?> makeVideoThumbnail(File video) =>
    _thumbnail(source: video.path, durationOf: () => _lengthOf(video));

/// Poster for a video that has no stored thumbnail. Made once per session.
Future<File?> posterFor({String? url, File? file}) {
  final key = file?.path ?? url ?? '';
  if (key.isEmpty) return Future.value(null);
  return _posterMemo.putIfAbsent(
    key,
    () => file != null
        ? makeVideoThumbnail(file)
        : _thumbnail(source: url!, durationOf: null),
  );
}

/// Time (ms) to take the frame at: a little way into the clip, past any
/// black fade-in, but never past the end.
int _frameTimeMs(Duration length) {
  if (length.inMilliseconds <= 0) return 1000;
  final wanted = (length.inMilliseconds * 0.2).round().clamp(500, 3000).toInt();
  final lastSafe = length.inMilliseconds - 200;
  return wanted < lastSafe ? wanted : (lastSafe > 0 ? lastSafe : 0);
}

Future<Duration> _lengthOf(File file) async {
  final c = VideoPlayerController.file(file);
  try {
    await c.initialize();
    return c.value.duration;
  } catch (_) {
    return Duration.zero;
  } finally {
    await c.dispose();
  }
}

Future<File?> _thumbnail({
  required String source,
  Future<Duration> Function()? durationOf,
}) async {
  try {
    final length = durationOf == null ? Duration.zero : await durationOf();
    final dir = await getTemporaryDirectory();
    final path = await VideoThumbnail.thumbnailFile(
      video: source,
      thumbnailPath: dir.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 720,
      quality: 80,
      timeMs: _frameTimeMs(length),
    );
    if (path == null || path.isEmpty) return null;
    return File(path);
  } catch (error) {
    debugPrint('Video thumbnail failed: $error');
    return null;
  }
}

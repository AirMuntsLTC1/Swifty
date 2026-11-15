// lib/helper/video_thumbnail_helper.dart
//
// Makes a still image (JPEG) from the first frame of a picked video. The
// image is uploaded next to the video and its URL is stored on the post or
// story, so the feed can show it instantly before the video starts.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Returns a temporary JPEG of the video, or null if it could not be made.
Future<File?> makeVideoThumbnail(File video) async {
  try {
    final dir = await getTemporaryDirectory();
    final path = await VideoThumbnail.thumbnailFile(
      video: video.path,
      thumbnailPath: dir.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 720,
      quality: 80,
      timeMs: 0,
    );
    if (path == null || path.isEmpty) return null;
    return File(path);
  } catch (error) {
    debugPrint('Video thumbnail failed: $error');
    return null;
  }
}

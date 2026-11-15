// lib/widgets/video/video_poster.dart
//
// The picture shown for a video before it plays. Order:
//   1. the stored thumbnail (thumbnail_url),
//   2. a poster made from the video itself (older posts),
//   3. a neutral grey tile with a film icon. Never black.
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/helper/video_thumbnail_helper.dart';
import 'package:flutter_twitter_clone/widgets/cache_image.dart';

class VideoPoster extends StatelessWidget {
  const VideoPoster({
    super.key,
    this.thumbnailUrl,
    this.videoUrl,
    this.videoFile,
    this.fit = BoxFit.cover,
  }) : assert(videoUrl != null || videoFile != null, 'Pass a url or a file');

  final String? thumbnailUrl;
  final String? videoUrl;
  final File? videoFile;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final thumb = thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) {
      return CacheImage(path: thumb, fit: fit, errorWidget: _placeholder());
    }
    return FutureBuilder<File?>(
      future: posterFor(url: videoUrl, file: videoFile),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Image.file(file, fit: fit, gaplessPlayback: true);
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return const ColoredBox(
      color: Color(0xFF2A3440),
      child: Center(
        child: Icon(Icons.movie_outlined, color: Colors.white38, size: 28),
      ),
    );
  }
}

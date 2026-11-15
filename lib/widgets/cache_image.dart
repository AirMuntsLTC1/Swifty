// lib/widgets/cache_image.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_twitter_clone/helper/constant.dart';
import 'package:flutter_twitter_clone/state/deviceSettings.dart';

class CacheImage extends StatelessWidget {
  const CacheImage({
    Key? key,
    this.path,
    this.fit = BoxFit.contain,
    this.errorWidget,
  }) : super(key: key);

  final String? path;
  final BoxFit fit;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    // Data saver decodes images at a smaller size, so fewer bytes are used.
    final maxWidth = DeviceSettings.instance.imageMaxWidth;
    return CachedNetworkImage(
      fit: fit,
      imageUrl: path ?? Constants.dummyProfilePic,
      memCacheWidth: maxWidth,
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: imageProvider,
            fit: fit,
          ),
        ),
      ),
      placeholderFadeInDuration: const Duration(milliseconds: 500),
      placeholder: (context, url) => Container(
        color: const Color(0xffeeeeee),
      ),
      cacheKey: path,
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            color: const Color(0xffeeeeee),
            child: Icon(
              LucideIcons.circleAlert,
              color: Colors.grey[700],
            ),
          ),
    );
  }
}

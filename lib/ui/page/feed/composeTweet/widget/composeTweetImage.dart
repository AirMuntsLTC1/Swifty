import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/video/post_video_player.dart';

class ComposeTweetImage extends StatelessWidget {
  final File? image;
  final File? video;
  final VoidCallback onCrossIconPressed;
  const ComposeTweetImage(
      {Key? key, this.image, this.video, required this.onCrossIconPressed})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    if (video != null) {
      return Stack(
        children: [
          PostVideoPlayer(file: video, borderRadius: 10),
          Align(
            alignment: Alignment.topRight,
            child: Container(
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.black54),
              child: IconButton(
                padding: const EdgeInsets.all(0),
                iconSize: 20,
                onPressed: onCrossIconPressed,
                icon: Icon(LucideIcons.x, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }
    return Container(
      child: image == null
          ? Container()
          : Stack(
              children: <Widget>[
                InteractiveViewer(
                  child: Container(
                    alignment: Alignment.topRight,
                    child: Container(
                      height: 220,
                      width: context.width * .8,
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                        image: DecorationImage(
                            image: FileImage(image!), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.all(0),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.black54),
                    child: IconButton(
                      padding: const EdgeInsets.all(0),
                      iconSize: 20,
                      onPressed: onCrossIconPressed,
                      icon: Icon(
                        LucideIcons.x,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                )
              ],
            ),
    );
  }
}





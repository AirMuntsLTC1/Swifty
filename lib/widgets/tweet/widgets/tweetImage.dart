import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/state/feedState.dart';
import 'package:flutter_twitter_clone/ui/page/feed/feedPostDetail.dart';
import 'package:flutter_twitter_clone/ui/page/feed/imageViewPage.dart';
import 'package:flutter_twitter_clone/widgets/cache_image.dart';
import 'package:flutter_twitter_clone/widgets/video/post_video_player.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:provider/provider.dart';

class TweetImage extends StatelessWidget {
  const TweetImage(
      {Key? key, required this.model, this.type, this.isRetweetImage = false})
      : super(key: key);

  final FeedModel model;
  final TweetType? type;
  final bool isRetweetImage;
  @override
  Widget build(BuildContext context) {
    if (model.imagePath != null) assert(type != null);
    if (model.imagePath != null && model.mediaKind == 'video') {
      // In the feed a tap opens the thread, like a photo does. Inside a thread
      // (and on replies) a tap pauses or plays the video instead.
      final opensThread = type == TweetType.Tweet;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: context.width * (type == TweetType.Detail ? .95 : .8) - 8,
            child: PostVideoPlayer(
              url: model.imagePath,
              thumbnailUrl: model.thumbnailUrl,
              borderRadius: isRetweetImage ? 0 : 20,
              autoPlayWhenVisible: true,
              startMuted: !opensThread,
              onTap: opensThread ? () => _openThread(context) : null,
            ),
          ),
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      alignment: Alignment.centerRight,
      child: model.imagePath == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                borderRadius: BorderRadius.all(
                  Radius.circular(isRetweetImage ? 0 : 20),
                ),
                onTap: () {
                  if (type == TweetType.ParentTweet) {
                    return;
                  }
                  final state = Provider.of<FeedState>(context, listen: false);
                  // A photo inside a thread or on a reply opens the previewer.
                  if (type == TweetType.Detail || type == TweetType.Reply) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImageViewPge(model: model),
                      ),
                    );
                    return;
                  }
                  // A photo in the feed, on a profile or in a retweet opens
                  // the post thread, the same as tapping the post.
                  if (type == TweetType.Tweet) {
                    state.clearAllDetailAndReplyTweetStack();
                  }
                  state.getPostDetailFromDatabase(null, model: model);
                  Navigator.push(context, FeedPostDetail.getRoute(model.key!));
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.all(
                    Radius.circular(isRetweetImage ? 0 : 20),
                  ),
                  child: Container(
                    width:
                        context.width * (type == TweetType.Detail ? .95 : .8) -
                            8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: CacheImage(
                        path: model.imagePath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// Same as tapping a post: open its thread.
  void _openThread(BuildContext context) {
    final state = Provider.of<FeedState>(context, listen: false);
    state.clearAllDetailAndReplyTweetStack();
    state.getPostDetailFromDatabase(null, model: model);
    Navigator.push(context, FeedPostDetail.getRoute(model.key!));
  }
}

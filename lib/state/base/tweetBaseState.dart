import 'dart:io';

import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// Shared tweet actions for widgets outside the feed.
class TweetBaseState extends AppState {
  SupabaseRepository get _repo => SupabaseRepository.instance;

  /// Fetch a post by id.
  Future<FeedModel?> getPostDetailFromDatabase(String postID) =>
      _repo.fetchPost(postID);

  /// Replies to a post, newest first.
  Future<List<FeedModel>?> getTweetsComments(FeedModel post) async {
    if (post.key == null) return [];
    return _repo.fetchComments(post.key!);
  }

  /// Delete a post (or a reply, when [type] is TweetType.Reply).
  bool deleteTweet(String tweetId, TweetType type) {
    try {
      if (type == TweetType.Reply) {
        _repo.deleteComment(tweetId).catchError((e) => cprint(e));
      } else {
        _repo.deletePost(tweetId).catchError((e) => cprint(e));
      }
      return true;
    } catch (error) {
      cprint(error, errorIn: 'deleteTweet');
      return false;
    }
  }

  /// Save the text of a post.
  void updateTweet(FeedModel model) {
    if (model.key == null) return;
    _repo
        .updatePostText(model.key!, model.description ?? '')
        .catchError((e) => cprint(e));
  }

  /// Like / unlike a post.
  void addLikeToTweet(FeedModel tweet, String userId) {
    final liked = !(tweet.likeList?.contains(userId) ?? false);
    tweet.likeList ??= [];
    if (liked) {
      tweet.likeList!.add(userId);
    } else {
      tweet.likeList!.removeWhere((id) => id == userId);
    }
    tweet.likeCount = tweet.likeList!.length;
    if (tweet.key != null) {
      _repo
          .setLike(tweet.key!, liked: liked)
          .catchError((e) => cprint(e, errorIn: 'addLikeToTweet'));
    }
    notifyListeners();
  }

  /// Create a post. Returns the new post id.
  Future<String?> createPost(FeedModel tweet) => _repo.createPost(
        text: tweet.description ?? '',
        tags: tweet.tags ?? const [],
        imageUrl: tweet.imagePath,
      );

  /// Upload an image to the post-media bucket and return its URL.
  Future<String?> uploadFile(File file) async {
    try {
      return await _repo.uploadFile(kPostMediaBucket, file);
    } catch (error) {
      cprint(error, errorIn: 'uploadFile');
      return null;
    }
  }
}

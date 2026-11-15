import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:translator/translator.dart';

import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// Home feed, tweet detail stack and replies.
///
/// Data source: Supabase `posts`, `post_media`, `post_likes`, `comments`,
/// `post_saves`. Updates arrive through Supabase Realtime.
class FeedState extends AppState {
  bool isBusy = false;
  Map<String, List<FeedModel>?>? tweetReplyMap = {};
  FeedModel? _tweetToReplyModel;
  FeedModel? get tweetToReplyModel => _tweetToReplyModel;
  set setTweetToReply(FeedModel model) {
    _tweetToReplyModel = model;
  }

  /// Ascending by createdAt. The public getter returns newest first.
  List<FeedModel>? _feedList;
  List<FeedModel>? _tweetDetailModelList;
  RealtimeChannel? _postsChannel;
  RealtimeChannel? _likesChannel;
  RealtimeChannel? _commentsChannel;

  List<FeedModel>? get tweetDetailModel => _tweetDetailModelList;

  SupabaseRepository get _repo => SupabaseRepository.instance;

  /// `feedList` always contains all loaded posts, newest first.
  List<FeedModel>? get feedList {
    if (_feedList == null) {
      return null;
    }
    return List.from(_feedList!.reversed);
  }

  /// Contain tweet list for home page.
  List<FeedModel>? getTweetList(UserModel? userModel) {
    if (userModel == null) {
      return null;
    }
    List<FeedModel>? list;
    if (feedList != null && feedList!.isNotEmpty) {
      list = feedList!.where((x) => x.parentkey == null).toList();
      if (list.isEmpty) {
        list = null;
      }
    }
    return list;
  }

  Map<String, dynamic> _linkWebInfos = {};
  Map<String, dynamic> get linkWebInfos => _linkWebInfos;
  void addWebInfo(String url, dynamic webInfo) {
    _linkWebInfos.addAll({url: webInfo});
  }

  Map<String, Translation?> _tweetsTranslations = {};
  Map<String, Translation?> get tweetsTranslations => _tweetsTranslations;
  void addTweetTranslation(String tweet, Translation? translation) {
    _tweetsTranslations.addAll({tweet: translation});
    notifyListeners();
  }

  /// set tweet for detail tweet page
  set setFeedModel(FeedModel model) {
    _tweetDetailModelList ??= [];
    _tweetDetailModelList!.add(model);
    cprint("Detail Tweet added. Total Tweet: ${_tweetDetailModelList!.length}");
    notifyListeners();
  }

  /// Remove last tweet from the detail page stack.
  void removeLastTweetDetail(String tweetKey) {
    if (_tweetDetailModelList != null && _tweetDetailModelList!.isNotEmpty) {
      final index = _tweetDetailModelList!.lastIndexWhere((x) => x.key == tweetKey);
      if (index >= 0) _tweetDetailModelList!.removeAt(index);
      tweetReplyMap?.removeWhere((key, value) => key == tweetKey);
      notifyListeners();
    }
  }

  /// Clear all tweets in the detail page and reply stacks.
  void clearAllDetailAndReplyTweetStack() {
    _tweetDetailModelList?.clear();
    tweetReplyMap?.clear();
    cprint('Empty tweets from stack');
  }

  /// Subscribe to realtime changes on posts, likes and comments.
  Future<bool> databaseInit() async {
    try {
      if (_postsChannel == null) {
        _postsChannel = _repo.db.channel('feed-posts')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'posts',
            callback: _onPostChange,
          )
          ..subscribe();
        _likesChannel = _repo.db.channel('feed-likes')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'post_likes',
            callback: _onRelatedChange,
          )
          ..subscribe();
        _commentsChannel = _repo.db.channel('feed-comments')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'comments',
            callback: _onRelatedChange,
          )
          ..subscribe();
      }
      return true;
    } catch (error) {
      cprint(error, errorIn: 'databaseInit');
      return false;
    }
  }

  @override
  void dispose() {
    for (final channel in [_postsChannel, _likesChannel, _commentsChannel]) {
      if (channel != null) _repo.db.removeChannel(channel);
    }
    _postsChannel = _likesChannel = _commentsChannel = null;
    super.dispose();
  }

  /// Load the home feed (newest posts, up to 60).
  void getDataFromDatabase() async {
    try {
      isBusy = true;
      _feedList = null;
      notifyListeners();
      final posts = await _repo.fetchPosts();
      _feedList = posts.reversed.toList();
      loadReposts();
      if (_feedList!.isEmpty) _feedList = null;
    } catch (error) {
      cprint(error, errorIn: 'getDataFromDatabase');
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Prepare a tweet for the detail page, then load its replies.
  void getPostDetailFromDatabase(String? postID, {FeedModel? model}) async {
    try {
      FeedModel? detail = model;
      if (model != null) {
        setFeedModel = model;
        postID = model.key;
      } else {
        assert(postID != null);
        detail = await _repo.fetchPost(postID!);
        if (detail != null) setFeedModel = detail;
      }
      if (detail != null && postID != null) {
        await _reloadComments(postID);
      }
    } catch (error) {
      cprint(error, errorIn: 'getPostDetailFromDatabase');
    }
  }

  /// Fetch a post, using the loaded feed first.
  Future<FeedModel?> fetchTweet(String postID) async {
    final cached = _feedList?.where((x) => x.key == postID);
    if (cached != null && cached.isNotEmpty) return cached.first;
    return _repo.fetchPost(postID);
  }

  /// Reason the last post failed, shown to the user in the composer.
  String? lastPostError;

  /// Create a new post. Returns the post id, or null when the post was not saved.
  Future<String?> createTweet(FeedModel model) async {
    isBusy = true;
    lastPostError = null;
    notifyListeners();
    String? tweetKey;
    try {
      final newId = await _repo.createPost(
        text: model.description ?? '',
        tags: model.tags ?? const [],
        imageUrl: model.imagePath,
      );
      tweetKey = newId;
      // Read the row back (with author and media) so it appears at once.
      // Short retries cover the moment before the row is readable. If it still
      // is not, the realtime listener adds it when it arrives.
      FeedModel? created;
      for (var attempt = 0; attempt < 3 && created == null; attempt++) {
        created = await _repo.fetchPost(newId);
        if (created == null) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
      if (created != null) _insertIntoFeed(created);
    } catch (error) {
      cprint(error, errorIn: 'createTweet');
      lastPostError = error.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
    return tweetKey;
  }

  /// Post ids the signed-in user has retweeted.
  Set<String> _reposted = {};
  bool isReposted(String? postId) => postId != null && _reposted.contains(postId);

  Future<void> loadReposts() async {
    try {
      _reposted = await _repo.fetchRepostedPostIds();
      notifyListeners();
    } catch (error) {
      cprint(error, errorIn: 'loadReposts');
    }
  }

  /// Retweet, or undo a retweet. The count changes at once and is reverted
  /// if the save fails.
  Future<void> toggleRepost(FeedModel model) async {
    final id = model.key;
    if (id == null) return;
    final wasReposted = _reposted.contains(id);
    final nowReposted = !wasReposted;
    _applyRepost(id, model, nowReposted);
    try {
      await _repo.setRepost(id, reposted: nowReposted);
    } catch (error) {
      cprint(error, errorIn: 'toggleRepost');
      _applyRepost(id, model, wasReposted);
    }
  }

  void _applyRepost(String id, FeedModel model, bool reposted) {
    if (reposted) {
      _reposted.add(id);
    } else {
      _reposted.remove(id);
    }
    final next = (model.retweetCount ?? 0) + (reposted ? 1 : -1);
    model.retweetCount = next < 0 ? 0 : next;
    notifyListeners();
  }

  /// Quote retweet: posts the comment and counts as a retweet of the original.
  Future<String?> createReTweet(FeedModel model) async {
    String? tweetKey;
    try {
      tweetKey = await createTweet(model);
      final original = model.childRetwetkey;
      if (tweetKey != null && original != null && !_reposted.contains(original)) {
        await _repo.setRepost(original, reposted: true);
        _reposted.add(original);
        notifyListeners();
      }
    } catch (error) {
      cprint(error, errorIn: 'createReTweet');
    }
    return tweetKey;
  }

  /// Delete a post, or a reply when [tweetId] belongs to a loaded comment list.
  void deleteTweet(String tweetId, TweetType type, {String? parentkey}) async {
    try {
      final isComment = tweetReplyMap?.values.any(
            (list) => list?.any((c) => c.key == tweetId) ?? false,
          ) ??
          false;

      final post = _feedList?.where((x) => x.key == tweetId).toList();
      if (isComment) {
        await _repo.deleteComment(tweetId);
        tweetReplyMap?.forEach((key, list) {
          list?.removeWhere((c) => c.key == tweetId);
        });
      } else {
        if (post != null && post.isNotEmpty && post.first.imagePath != null) {
          await _repo.deleteStorageUrl(kPostMediaBucket, post.first.imagePath!);
        }
        await _repo.deletePost(tweetId);
        _feedList?.removeWhere((x) => x.key == tweetId);
      }

      _tweetDetailModelList?.removeWhere((x) => x.key == tweetId);
      if (_tweetDetailModelList != null && _tweetDetailModelList!.isEmpty) {
        _tweetDetailModelList = null;
      }
      cprint('Tweet deleted');
      notifyListeners();
    } catch (error) {
      cprint(error, errorIn: 'deleteTweet');
    }
  }

  /// Upload [file] to the post-media bucket and return its public URL.
  Future<String?> uploadFile(File file) async {
    try {
      isBusy = true;
      notifyListeners();
      return await _repo.uploadFile(kPostMediaBucket, file);
    } catch (error) {
      cprint(error, errorIn: 'uploadFile');
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Delete a file from the post-media bucket by its public URL.
  Future<void> deleteFile(String url, String baseUrl) async {
    try {
      await _repo.deleteStorageUrl(kPostMediaBucket, url);
    } catch (error) {
      cprint(error, errorIn: 'deleteFile');
    }
  }

  /// Update the text of one of the user's posts.
  Future<void> updateTweet(FeedModel model) async {
    if (model.key == null) return;
    await _repo.updatePostText(model.key!, model.description ?? '');
  }

  /// Like / unlike a post. The like notification is created by the
  /// `swifly_on_like` trigger in the database.
  void addLikeToTweet(FeedModel tweet, String userId) {
    final liked = !(tweet.likeList?.contains(userId) ?? false);
    tweet.likeList ??= [];
    if (liked) {
      tweet.likeList!.add(userId);
    } else {
      tweet.likeList!.removeWhere((id) => id == userId);
    }
    tweet.likeCount = tweet.likeList!.length;
    notifyListeners();
    if (tweet.key != null) {
      _repo.setLike(tweet.key!, liked: liked).catchError((error) {
        cprint(error, errorIn: 'addLikeToTweet');
      });
    }
  }

  /// Add a reply to the tweet set with [setTweetToReply].
  /// Replies are rows in the `comments` table. A reply to a reply keeps the post
  /// id and sets `parent_id`.
  Future<String?> addCommentToPost(FeedModel replyTweet) async {
    final target = _tweetToReplyModel;
    if (target == null) return null;
    isBusy = true;
    notifyListeners();
    try {
      final isNested = target.parentkey != null;
      final postId = isNested ? target.parentkey! : target.key!;
      final commentId = await _repo.addComment(
        postId: postId,
        text: replyTweet.description ?? '',
        parentId: isNested ? target.key : null,
        imageUrl: replyTweet.imagePath,
      );
      target.replyTweetKeyList ??= [];
      target.replyTweetKeyList!.add(commentId);
      target.commentCount = (target.commentCount ?? 0) + 1;
      await _reloadComments(postId);
      return commentId;
    } catch (error) {
      cprint(error, errorIn: 'addCommentToPost');
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Save a post to bookmarks.
  Future addBookmark(String tweetId) async {
    await _repo.setSave(tweetId, saved: true);
  }

  /// Remove a post from bookmarks.
  Future removeBookmark(String tweetId) async {
    await _repo.setSave(tweetId, saved: false);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _insertIntoFeed(FeedModel model) {
    _feedList ??= <FeedModel>[];
    final index = _feedList!.indexWhere((x) => x.key == model.key);
    if (index >= 0) {
      _feedList![index] = model;
    } else {
      _feedList!.add(model);
    }
    _feedList!.sort((x, y) => DateTime.parse(x.createdAt)
        .compareTo(DateTime.parse(y.createdAt)));
  }

  Future<void> _reloadComments(String postId) async {
    final comments = await _repo.fetchComments(postId);
    tweetReplyMap ??= {};
    tweetReplyMap![postId] = comments;
    final parent = _feedList?.where((x) => x.key == postId);
    if (parent != null && parent.isNotEmpty) {
      parent.first.commentCount = comments.length;
    }
    notifyListeners();
  }

  Future<void> _refreshPost(String postId) async {
    final model = await _repo.fetchPost(postId);
    if (model == null) {
      _feedList?.removeWhere((x) => x.key == postId);
    } else {
      _insertIntoFeed(model);
      if (_tweetDetailModelList != null) {
        for (var i = 0; i < _tweetDetailModelList!.length; i++) {
          if (_tweetDetailModelList![i].key == postId) {
            _tweetDetailModelList![i] = model;
          }
        }
      }
    }
    notifyListeners();
  }

  void _onPostChange(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = payload.oldRecord['id']?.toString();
      if (id != null) {
        _feedList?.removeWhere((x) => x.key == id);
        notifyListeners();
      }
      return;
    }
    final id = payload.newRecord['id']?.toString();
    if (id != null) _refreshPost(id);
  }

  void _onRelatedChange(PostgresChangePayload payload) {
    final record = payload.eventType == PostgresChangeEvent.delete
        ? payload.oldRecord
        : payload.newRecord;
    final postId = record['post_id']?.toString();
    if (postId == null) return;
    if (tweetReplyMap != null && tweetReplyMap!.containsKey(postId)) {
      _reloadComments(postId);
    }
    _refreshPost(postId);
  }
}





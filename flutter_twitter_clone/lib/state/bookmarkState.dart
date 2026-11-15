import 'dart:async';

import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/bookmarkModel.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// Bookmarked posts. Stored in the `post_saves` table.
class BookmarkState extends AppState {
  BookmarkState() {
    getDataFromDatabase();
  }

  List<FeedModel>? _tweetList;
  List<BookmarkModel>? _bookmarkList;

  void addBookmarkTweetToList(BookmarkModel model) {
    _bookmarkList ??= <BookmarkModel>[];
    if (!_bookmarkList!.any((element) => element.key == model.key)) {
      _bookmarkList!.add(model);
    }
  }

  List<FeedModel>? get tweetList => _tweetList;

  /// Load the signed-in user's saved posts.
  void getDataFromDatabase() async {
    if (_tweetList != null) return;
    isBusy = true;
    try {
      final ids = await SupabaseRepository.instance.fetchSavedPostIds();
      _bookmarkList = ids
          .map((id) => BookmarkModel(
                key: id,
                tweetId: id,
                createdAt: DateTime.now().toUtc().toIso8601String(),
              ))
          .toList();
      final posts = await SupabaseRepository.instance.fetchPosts(postIds: ids);
      _tweetList = posts;
    } catch (error) {
      cprint(error, errorIn: 'getDataFromDatabase');
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Get a single post that is in the bookmarks.
  Future<FeedModel?> getTweetDetail(String tweetId) {
    return SupabaseRepository.instance.fetchPost(tweetId);
  }
}



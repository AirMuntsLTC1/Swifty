import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/searchState.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// Compose screen state: @mention suggestions and submit button.
class ComposeTweetState extends ChangeNotifier {
  bool showUserList = false;
  bool enableSubmitButton = false;
  bool hideUserList = false;
  String description = "";
  String? serverToken;
  final usernameRegex = r'(@\w*[a-zA-Z1-9]$)';

  bool _isScrollingDown = false;
  bool get isScrollingDown => _isScrollingDown;
  set setIsScrollingDown(bool value) {
    _isScrollingDown = value;
    notifyListeners();
  }

  /// Show the user list while the last word is an @mention.
  bool get displayUserList {
    RegExp regExp = RegExp(usernameRegex);
    var status = regExp.hasMatch(description);
    return status && !hideUserList;
  }

  /// Hide user list when a user is picked from it.
  void onUserSelected() {
    hideUserList = true;
    notifyListeners();
  }

  /// Runs on every change of the description text.
  void onDescriptionChanged(String text, SearchState searchState) {
    final wasSubmit = enableSubmitButton;
    final wasList = displayUserList;

    description = text;
    hideUserList = false;
    enableSubmitButton = text.isNotEmpty && text.length <= 280;

    final regExp = RegExp(usernameRegex);
    if (text.isNotEmpty && regExp.hasMatch(text)) {
      final matches = regExp.allMatches(text);
      final name = text.substring(matches.last.start, matches.last.end);
      searchState.filterByUsername(text.endsWith('@') ? '' : name);
    }

    // Notify only when a visible value changes, so typing stays smooth.
    if (wasSubmit != enableSubmitButton || wasList != displayUserList) {
      notifyListeners();
    }
  }

  /// Replace the last @mention with the picked username.
  String getDescription(String username) {
    RegExp regExp = RegExp(usernameRegex);
    Iterable<Match> matches = regExp.allMatches(description);
    var name = description.substring(0, matches.last.start);
    description = '$name $username';
    return description;
  }

  /// Kept for compatibility. Mentions are stored in Supabase; no key is needed.
  Future<void> getFCMServerKey() async {}

  /// Store a mention notification for every mentioned user in [model].
  Future<void> sendNotification(FeedModel model, SearchState state) async {
    final text = model.description ?? '';
    final handles = RegExp(r'@\w+')
        .allMatches(text)
        .map((m) => m.group(0)!.toLowerCase())
        .toSet();
    if (handles.isEmpty) return;
    final me = SupabaseRepository.instance.uid;
    for (final user in state.userlist ?? const <UserModel>[]) {
      final handle = (user.userName ?? '').toLowerCase();
      if (handle.isNotEmpty && handles.contains(handle) && user.userId != me) {
        await sendNotificationToUser(model, user);
      }
    }
  }

  /// Insert a mention notification row for [user].
  Future<void> sendNotificationToUser(FeedModel model, UserModel user) async {
    if (model.key == null || user.userId == null) return;
    await SupabaseRepository.instance.insertMentionNotification(
      userId: user.userId!,
      postId: model.key!,
      preview: model.description,
    );
  }
}





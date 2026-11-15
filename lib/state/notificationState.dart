// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/helper/constant.dart';
import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/notificationModel.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/resource/push_notification_service.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';
import 'package:flutter_twitter_clone/ui/page/common/locator.dart';

/// Activity list stored in `public.notifications`.
class NotificationState extends AppState {
  List<UserModel> userList = [];

  List<NotificationModel>? _notificationList;
  RealtimeChannel? _channel;
  String? _activeUserId;
  Timer? _refreshTimer;
  bool _loadingRows = false;
  bool _reloadRequested = false;

  SupabaseRepository get _repo => SupabaseRepository.instance;

  void addNotificationList(NotificationModel model) {
    _notificationList ??= <NotificationModel>[];
    if (!_notificationList!.any((element) => element.id == model.id)) {
      _notificationList!.insert(0, model);
      notifyListeners();
    }
  }

  List<NotificationModel>? get notificationList => _notificationList;

  /// Subscribe once per signed-in account. INSERT creates visible activity;
  /// DELETE removes it. Read-state UPDATEs are intentionally ignored to avoid
  /// refetch loops when opening the notifications page marks rows as read.
  Future<bool> databaseInit(String userId) async {
    if (userId.isEmpty) return false;
    if (_activeUserId == userId && _channel != null) return true;

    try {
      final previous = _channel;
      _channel = null;
      _activeUserId = userId;
      if (previous != null) await _repo.db.removeChannel(previous);

      final channel = _repo.db.channel('notifications-$userId');
      _channel = channel
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _queueRefresh(userId),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          callback: (_) => _queueRefresh(userId),
        )
        ..subscribe((status, error) {
          debugPrint('Notifications Realtime [$userId]: $status${error == null ? '' : ' ($error)'}');
          if (status == RealtimeSubscribeStatus.subscribed) {
            getDataFromDatabase(userId, force: true);
          }
        });
      return true;
    } catch (error) {
      cprint(error, errorIn: 'databaseInit');
      return false;
    }
  }

  void _queueRefresh(String userId) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (_activeUserId == userId) {
        getDataFromDatabase(userId, force: true);
      }
    });
  }

  /// Load notifications. Likes are grouped by post and follows by user.
  Future<void> getDataFromDatabase(String userId, {bool force = false}) async {
    if (userId.isEmpty || (_activeUserId != null && _activeUserId != userId)) {
      return;
    }
    if (_notificationList != null && !force) return;
    if (_loadingRows) {
      _reloadRequested = true;
      return;
    }

    _loadingRows = true;
    isBusy = true;
    try {
      do {
        _reloadRequested = false;
        final rows = await _repo.fetchNotifications(userId);
        if (_activeUserId == null || _activeUserId == userId) {
          _notificationList = _group(rows);
        }
      } while (_reloadRequested && _activeUserId == userId);
    } catch (error) {
      cprint(error, errorIn: 'getDataFromDatabase');
    } finally {
      _loadingRows = false;
      isBusy = false;
      notifyListeners();
    }
  }

  List<NotificationModel> _group(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    final result = <NotificationModel>[];
    for (final row in rows) {
      final rawType = row['type']?.toString() ?? 'activity';
      final type = _typeFor(rawType);
      final postId = row['post_id']?.toString();
      final actorId = row['actor_id']?.toString() ?? '';
      final isFollow = rawType == 'follow';
      final isList = type == NotificationType.ListActivity.toString();
      final hasPost = postId != null && postId.isNotEmpty;

      // Messages belong in the chat inbox, not the activity page.
      if (rawType == 'message') continue;
      final listId = row['list_id']?.toString();
      if (isList && (listId == null || listId.isEmpty)) continue;

      final genericActivity = !isFollow && !isList && !hasPost;
      final groupKey = isFollow
          ? 'follow:$actorId'
          : isList
              ? 'list:$listId:$actorId:$rawType'
              : hasPost
                  ? 'post:$postId:$type'
                  : 'activity:${row['id']}';
      if (!seen.add(groupKey)) continue;

      final createdAt = row['created_at']?.toString();
      final actorName = (row['actor_name'] ?? row['actor_handle'] ?? 'Someone')
          .toString();
      final avatar = (row['avatar_url'] ?? '').toString();
      final data = isFollow
          ? <String, dynamic>{
              'userId': actorId,
              'displayName': actorName,
              'userName': '@${(row['actor_handle'] ?? '').toString()}',
              'profilePic': avatar.isNotEmpty ? avatar : Constants.dummyProfilePic,
              'bio': '',
              'isVerified': false,
            }
          : isList
              ? <String, dynamic>{
                  'listId': listId,
                  'kind': rawType,
                  'listName': (row['preview'] ?? '').toString(),
                  'userId': actorId,
                  'displayName': actorName,
                  'profilePic': avatar.isNotEmpty ? avatar : Constants.dummyProfilePic,
                }
              : genericActivity
                  ? <String, dynamic>{
                      'genericActivity': true,
                      'kind': rawType,
                      'userId': actorId,
                      'displayName': actorName,
                      'userName': (row['actor_handle'] ?? '').toString(),
                      'profilePic': avatar.isNotEmpty ? avatar : Constants.dummyProfilePic,
                      'preview': (row['preview'] ?? '').toString(),
                      'emoji': (row['emoji'] ?? '').toString(),
                    }
                  : <String, dynamic>{};

      result.add(NotificationModel(
        id: row['id'].toString(),
        tweetKey: hasPost ? postId : null,
        type: genericActivity ? NotificationType.Tweet.toString() : type,
        createdAt: createdAt,
        updatedAt: createdAt,
        data: data,
      ));
    }
    return result;
  }

  String _typeFor(String raw) {
    switch (raw) {
      case 'like':
        return NotificationType.Like.toString();
      case 'comment':
      case 'reply':
        return NotificationType.Reply.toString();
      case 'follow':
        return NotificationType.Follow.toString();
      case 'mention':
        return NotificationType.Mention.toString();
      case 'message':
        return NotificationType.Message.toString();
      case 'retweet':
        return NotificationType.Retweet.toString();
      case 'list_add':
      case 'list_join':
      case 'list_request':
      case 'list_request_accepted':
      case 'list_post':
        return NotificationType.ListActivity.toString();
      default:
        return NotificationType.Tweet.toString();
    }
  }

  Future<FeedModel?> getTweetDetail(String tweetId) =>
      _repo.fetchPost(tweetId);

  Future<UserModel?> getUserDetail(String userId) async {
    final cached = userList.where((x) => x.userId == userId);
    if (cached.isNotEmpty) return cached.first;
    final user = await _repo.fetchUser(userId);
    if (user != null) userList.add(user);
    return user;
  }

  void removeNotification(String userId, String tweetkey) async {
    try {
      await _repo.deleteNotificationsForPost(userId, tweetkey);
      _notificationList?.removeWhere((x) => x.tweetKey == tweetkey);
      notifyListeners();
    } catch (error) {
      cprint(error, errorIn: 'removeNotification');
    }
  }

  /// Start FCM once after sign-in. This also registers the current device token.
  void initFirebaseService() {
    if (!getIt.isRegistered<PushNotificationService>()) {
      getIt.registerSingleton<PushNotificationService>(PushNotificationService());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final channel = _channel;
    _channel = null;
    _activeUserId = null;
    if (channel != null) unawaited(_repo.db.removeChannel(channel));
    if (getIt.isRegistered<PushNotificationService>()) {
      final service = getIt<PushNotificationService>();
      unawaited(service.dispose());
      getIt.unregister<PushNotificationService>();
    }
    super.dispose();
  }
}





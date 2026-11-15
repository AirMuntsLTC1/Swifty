// ignore_for_file: avoid_print

import 'dart:async';

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

/// Activity list (likes, comments, follows, mentions). Stored in the
/// `notifications` table; the database triggers create most rows.
class NotificationState extends AppState {
  List<UserModel> userList = [];

  List<NotificationModel>? _notificationList;
  RealtimeChannel? _channel;

  SupabaseRepository get _repo => SupabaseRepository.instance;

  void addNotificationList(NotificationModel model) {
    _notificationList ??= <NotificationModel>[];
    if (!_notificationList!.any((element) => element.id == model.id)) {
      _notificationList!.insert(0, model);
    }
  }

  List<NotificationModel>? get notificationList => _notificationList;

  /// Subscribe to new notifications for [userId].
  Future<bool> databaseInit(String userId) async {
    try {
      if (_channel != null) {
        await _repo.db.removeChannel(_channel!);
        _channel = null;
      }
      _channel = _repo.db.channel('notifications-$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {
            getDataFromDatabase(userId, force: true);
          },
        )
        ..subscribe();
      return true;
    } catch (error) {
      cprint(error, errorIn: 'databaseInit');
      return false;
    }
  }

  /// Load notifications. Likes are grouped by post and follows by user.
  Future<void> getDataFromDatabase(String userId, {bool force = false}) async {
    if (_notificationList != null && !force) return;
    isBusy = true;
    try {
      final rows = await _repo.fetchNotifications(userId);
      _notificationList = _group(rows);
    } catch (error) {
      cprint(error, errorIn: 'getDataFromDatabase');
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  List<NotificationModel> _group(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    final result = <NotificationModel>[];
    for (final row in rows) {
      final rawType = row['type']?.toString() ?? '';
      final type = _typeFor(rawType);
      final postId = row['post_id']?.toString();
      final actorId = row['actor_id']?.toString() ?? '';
      final isFollow = type == NotificationType.Follow.toString();

      // Messages are shown in the chat tab, not here.
      if (type == NotificationType.Message.toString()) continue;
      final isList = type == NotificationType.ListAdd.toString();
      final listId = row['list_id']?.toString();
      if (isList && listId == null) continue;
      if (!isFollow && !isList && postId == null) continue;

      final groupKey = isFollow
          ? 'follow:$actorId'
          : isList
              ? 'list:$listId:$actorId'
              : 'post:$postId:$type';
      if (!seen.add(groupKey)) continue;

      final createdAt = row['created_at']?.toString();
      final data = isFollow
          ? <String, dynamic>{
              'userId': actorId,
              'displayName': (row['actor_name'] ?? '').toString(),
              'userName': '@${(row['actor_handle'] ?? '').toString()}',
              'profilePic': (row['avatar_url'] ?? '').toString().isNotEmpty
                  ? row['avatar_url'].toString()
                  : Constants.dummyProfilePic,
              'bio': '',
              'isVerified': false,
            }
          : isList
              ? <String, dynamic>{
                  'listId': listId,
                  'listName': (row['preview'] ?? '').toString(),
                  'userId': actorId,
                  'displayName': (row['actor_name'] ?? '').toString(),
                  'profilePic': (row['avatar_url'] ?? '').toString().isNotEmpty
                      ? row['avatar_url'].toString()
                      : Constants.dummyProfilePic,
                }
              : <String, dynamic>{};

      result.add(NotificationModel(
        id: row['id'].toString(),
        tweetKey: postId,
        type: type,
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
        return NotificationType.ListAdd.toString();
      default:
        return NotificationType.Tweet.toString();
    }
  }

  /// Get a post referenced by a notification.
  Future<FeedModel?> getTweetDetail(String tweetId) =>
      _repo.fetchPost(tweetId);

  /// Get the user who liked / followed.
  Future<UserModel?> getUserDetail(String userId) async {
    final cached = userList.where((x) => x.userId == userId);
    if (cached.isNotEmpty) return cached.first;
    final user = await _repo.fetchUser(userId);
    if (user != null) userList.add(user);
    return user;
  }

  /// Remove the notifications for a post that was deleted or is not available.
  void removeNotification(String userId, String tweetkey) async {
    try {
      await _repo.deleteNotificationsForPost(userId, tweetkey);
      _notificationList?.removeWhere((x) => x.tweetKey == tweetkey);
      notifyListeners();
    } catch (error) {
      cprint(error, errorIn: 'removeNotification');
    }
  }

  /// Start the push service once. Registers the device token.
  void initFirebaseService() {
    if (!getIt.isRegistered<PushNotificationService>()) {
      getIt.registerSingleton<PushNotificationService>(
          PushNotificationService());
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      _repo.db.removeChannel(_channel!);
      _channel = null;
    }
    if (getIt.isRegistered<PushNotificationService>()) {
      getIt.unregister<PushNotificationService>();
    }
    super.dispose();
  }
}

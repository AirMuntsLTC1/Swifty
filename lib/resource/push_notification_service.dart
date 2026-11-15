import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/model/push_notification_model.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// Push delivery uses FCM only as the device transport. Notifications are
/// stored in Supabase and sent by the `push-notify` Edge Function, which
/// reads device tokens from `user_devices`. This class saves the device token
/// and forwards notification taps to the UI.
class PushNotificationService {
  PushNotificationService() {
    _init();
  }

  final StreamController<PushNotificationModel> _controller =
      StreamController<PushNotificationModel>.broadcast();

  Stream<PushNotificationModel> get pushNotificationResponseStream =>
      _controller.stream;

  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _tokenSub;

  Future<void> _init() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_emit);
      _tokenSub = messaging.onTokenRefresh.listen((token) {
        _register(token);
      });
      final initial = await messaging.getInitialMessage();
      if (initial != null) _emit(initial);
      await registerCurrentDeviceToken();
    } catch (error) {
      debugPrint('Push notifications not available: $error');
    }
  }

  /// Save this device's FCM token in Supabase (`user_devices`).
  static Future<void> registerCurrentDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
    } catch (error) {
      debugPrint('Could not register push token: $error');
    }
  }

  static Future<void> _register(String token) {
    final platform = Platform.isIOS ? 'ios' : 'android';
    return SupabaseRepository.instance.registerPushToken(token, platform);
  }

  void _emit(RemoteMessage message) {
    final kind = message.data['kind']?.toString() ?? '';
    _controller.add(PushNotificationModel(
      id: message.messageId ?? '',
      type: _typeFor(kind),
      receiverId: SupabaseRepository.instance.uid ?? '',
      senderId: message.data['sender_id']?.toString() ?? '',
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      tweetId: message.data['post_id']?.toString() ?? '',
    ));
  }

  String _typeFor(String kind) {
    switch (kind) {
      case 'message':
        return NotificationType.Message.toString();
      case 'mention':
        return NotificationType.Mention.toString();
      case 'follow':
        return NotificationType.Follow.toString();
      case 'comment':
        return NotificationType.Reply.toString();
      case 'like':
        return NotificationType.Like.toString();
      default:
        return NotificationType.Tweet.toString();
    }
  }

  void dispose() {
    _openedSub?.cancel();
    _tokenSub?.cancel();
    _controller.close();
  }
}

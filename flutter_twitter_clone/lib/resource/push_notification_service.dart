import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/model/push_notification_model.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// FCM transports notifications while the app is in the background. When the
/// app is visible, Android notifications are displayed through MainActivity's
/// native notification channel because FCM does not display foreground
/// notification payloads automatically.
class PushNotificationService {
  PushNotificationService() {
    _init();
  }

  static const MethodChannel _nativeNotifications =
      MethodChannel('com.swifs.swifs/native_notifications');
  static const String channelId = 'swifs_social_notifications';

  final StreamController<PushNotificationModel> _controller =
      StreamController<PushNotificationModel>.broadcast();

  Stream<PushNotificationModel> get pushNotificationResponseStream =>
      _controller.stream;

  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenSub;
  bool _disposed = false;

  Future<void> _init() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM notification permission: ${settings.authorizationStatus}');
      await messaging.setAutoInitEnabled(true);

      // MainActivity also creates this channel before Flutter starts. Calling
      // this method is harmless and makes the channel setup explicit.
      try {
        await _nativeNotifications.invokeMethod<bool>('createChannel');
      } on MissingPluginException {
        // Non-Android platforms do not implement the Android bridge.
      } catch (error) {
        debugPrint('Native notification channel setup failed: $error');
      }

      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_emit);
      _foregroundSub = FirebaseMessaging.onMessage.listen(_showForeground);
      _tokenSub = messaging.onTokenRefresh.listen((token) {
        _register(token).catchError((Object error) {
          debugPrint('Refreshed FCM token registration failed: $error');
        });
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
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      final token = await messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _register(token);
      } else {
        debugPrint('FCM did not return a device token.');
      }
    } catch (error) {
      debugPrint('Could not register push token: $error');
    }
  }

  static Future<void> _register(String token) {
    final platform = Platform.isIOS ? 'ios' : 'android';
    return SupabaseRepository.instance.registerPushToken(token, platform);
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final data = message.data;
    final title = (message.notification?.title ?? data['title'] ?? 'Swifs')
        .toString()
        .trim();
    final body = (message.notification?.body ?? data['body'] ?? '')
        .toString()
        .trim();
    if (body.isEmpty || _disposed) return;

    final stableId = (data['tag'] ??
            data['notification_id'] ??
            message.messageId ??
            '${DateTime.now().microsecondsSinceEpoch}')
        .toString();
    final stringData = <String, String>{
      for (final entry in data.entries) entry.key: entry.value.toString(),
    };

    try {
      final shown = await _nativeNotifications.invokeMethod<bool>(
        'showNotification',
        <String, dynamic>{
          'id': stableId.hashCode,
          'title': title.isEmpty ? 'Swifs' : title,
          'body': body,
          'data': stringData,
        },
      );
      debugPrint('Foreground native notification displayed: ${shown == true}');
    } on MissingPluginException {
      debugPrint('Native notification bridge is unavailable on this platform.');
    } catch (error) {
      debugPrint('Could not display foreground notification: $error');
    }
  }

  void _emit(RemoteMessage message) {
    if (_disposed || _controller.isClosed) return;
    final data = message.data;
    final kind = data['kind']?.toString() ?? '';
    _controller.add(PushNotificationModel(
      id: message.messageId ?? data['notification_id']?.toString() ?? '',
      type: _typeFor(kind),
      receiverId: SupabaseRepository.instance.uid ?? '',
      senderId: (data['sender_id'] ?? data['actor_id'] ?? '').toString(),
      title: message.notification?.title ?? data['title']?.toString() ?? '',
      body: message.notification?.body ?? data['body']?.toString() ?? '',
      tweetId: data['post_id']?.toString() ?? '',
    ));
  }

  String _typeFor(String kind) {
    switch (kind) {
      case 'message':
        return NotificationType.Message.toString();
      case 'mention':
        return NotificationType.Mention.toString();
      case 'follow':
      case 'follow_request':
      case 'follow_accept':
        return NotificationType.Follow.toString();
      case 'comment':
      case 'reply':
        return NotificationType.Reply.toString();
      case 'like':
        return NotificationType.Like.toString();
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

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _openedSub?.cancel();
    await _foregroundSub?.cancel();
    await _tokenSub?.cancel();
    await _controller.close();
  }
}



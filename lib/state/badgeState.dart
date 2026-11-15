import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// Unread counts behind the red badges: notifications and direct messages.
/// Realtime tells us when a notification or message changes; the counts come
/// from the swifly_unread_counts() function.
class BadgeState extends ChangeNotifier {
  int notifications = 0;
  int messages = 0;

  RealtimeChannel? _channel;
  String? _userId;

  SupabaseRepository get _repo => SupabaseRepository.instance;

  /// Subscribes for [userId] and loads the counts. Safe to call again.
  Future<void> start(String userId) async {
    if (_userId == userId && _channel != null) {
      await refresh();
      return;
    }
    await stop();
    _userId = userId;
    _channel = _repo.db.channel('badges-$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => refresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient',
          value: userId,
        ),
        callback: (_) => refresh(),
      )
      ..subscribe();
    await refresh();
  }

  Future<void> refresh() async {
    if (_userId == null) return;
    try {
      final rows = List<Map<String, dynamic>>.from(
        await _repo.db.rpc('swifly_unread_counts') as List,
      );
      final row = rows.isEmpty ? <String, dynamic>{} : rows.first;
      notifications = (row['notifications'] as num?)?.toInt() ?? 0;
      messages = (row['messages'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (error) {
      debugPrint('Badge refresh failed: $error');
    }
  }

  /// Called when the Notifications tab is opened: marks them read.
  Future<void> clearNotifications() async {
    final me = _userId;
    if (me == null) return;
    try {
      await _repo.markNotificationsRead(me);
    } catch (_) {}
    await refresh();
  }

  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    _userId = null;
    if (channel != null) {
      await _repo.db.removeChannel(channel);
    }
  }
}

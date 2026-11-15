import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// Unread counts for activity notifications and incoming direct messages.
class BadgeState extends ChangeNotifier {
  int notifications = 0;
  int messages = 0;

  RealtimeChannel? _channel;
  String? _userId;

  SupabaseRepository get _repo => SupabaseRepository.instance;

  Future<void> start(String userId) async {
    if (userId.isEmpty) return;
    if (_userId == userId && _channel != null) {
      await refresh();
      return;
    }
    await stop();
    _userId = userId;
    final channel = _repo.db.channel('badges-$userId');
    _channel = channel
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
      ..subscribe((status, error) {
        debugPrint('Badge Realtime [$userId]: $status${error == null ? '' : ' ($error)'}');
        if (status == RealtimeSubscribeStatus.subscribed) refresh();
      });
    await refresh();
  }

  Future<void> refresh() async {
    if (_userId == null) return;
    try {
      final rows = List<Map<String, dynamic>>.from(
        await _repo.db.rpc('swifly_unread_counts') as List,
      );
      if (rows.isEmpty) {
        notifications = 0;
        messages = 0;
      } else {
        notifications = (rows.first['notifications'] as num?)?.toInt() ?? 0;
        messages = (rows.first['messages'] as num?)?.toInt() ?? 0;
      }
      notifyListeners();
    } catch (error) {
      debugPrint('Badge refresh failed: $error');
    }
  }

  Future<void> clearNotifications() async {
    final me = _userId;
    if (me == null) return;
    try {
      await _repo.markNotificationsRead(me);
    } catch (error) {
      debugPrint('Mark notifications read failed: $error');
    }
    await refresh();
  }

  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    _userId = null;
    if (channel != null) await _repo.db.removeChannel(channel);
  }
}

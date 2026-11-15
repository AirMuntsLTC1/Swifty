import 'package:flutter/foundation.dart';

import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// Account settings shown on the privacy, direct-message and notification
/// pages. Values are loaded from `user_settings` once per signed-in account,
/// shown immediately when changed, and rolled back if the save fails.
class SettingsState extends ChangeNotifier {
  /// Page switch key -> default value (used before the row loads).
  static const Map<String, bool> _defaults = {
    'protected': false,
    'receive_message_requests': true,
    'read_receipts': true,
    'sensitive_media_display': false,
    'sensitive_media_mark': false,
    'live_video': true,
    'push_notifications': true,
  };

  final Map<String, bool> _values = Map<String, bool>.from(_defaults);
  String? _loadedFor;
  bool _loading = false;

  SupabaseRepository get _repo => SupabaseRepository.instance;

  bool get(String key) => _values[key] ?? _defaults[key] ?? false;

  /// Loads the settings row for the current user, once per account.
  Future<void> ensureLoaded() async {
    final me = _repo.uid;
    if (me == null || _loading || _loadedFor == me) return;
    _loading = true;
    try {
      final row = await _repo.fetchUserSettings();
      _values
        ..clear()
        ..addAll(_defaults);
      for (final key in _defaults.keys) {
        final value = _fromRow(key, row);
        if (value != null) _values[key] = value;
      }
      _loadedFor = me;
    } catch (error) {
      debugPrint('settings load failed: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Updates one switch right away, then saves it. Reverts on failure.
  Future<void> set(String key, bool value) async {
    final previous = get(key);
    _values[key] = value;
    notifyListeners();
    try {
      await _repo.upsertUserSettings(_toRow(key, value));
    } catch (error) {
      debugPrint('settings save failed: $error');
      _values[key] = previous;
      notifyListeners();
    }
  }

  /// Maps a page switch onto its `user_settings` column.
  static Map<String, dynamic> _toRow(String key, bool value) {
    switch (key) {
      case 'protected':
        return {'account_privacy': value ? 'protected' : 'public'};
      case 'receive_message_requests':
        return {'messages_audience': value ? 'everyone' : 'followers'};
      default:
        return {key: value};
    }
  }

  static bool? _fromRow(String key, Map<String, dynamic> row) {
    switch (key) {
      case 'protected':
        final v = row['account_privacy'];
        return v == null ? null : v == 'protected';
      case 'receive_message_requests':
        final v = row['messages_audience'];
        return v == null ? null : v == 'everyone';
      default:
        final v = row[key];
        return v is bool ? v : null;
    }
  }
}

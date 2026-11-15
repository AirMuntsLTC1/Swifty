// lib/state/settingsState.dart
//
// Account settings. They follow the signed-in person on every device.
// Settings that have their own user_settings column keep it. Everything else
// is stored in the `prefs` jsonb column. Changes show at once and roll back
// if the save fails.
import 'package:flutter/foundation.dart';

import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

class SettingsState extends ChangeNotifier {
  /// Every account setting and its default value.
  static const Map<String, Object> defaults = {
    // Columns on user_settings.
    'protected': false,
    'receive_message_requests': true,
    'read_receipts': true,
    'sensitive_media_display': false,
    'sensitive_media_mark': false,
    'live_video': true,
    'push_notifications': true,
    // Stored in user_settings.prefs.
    'photo_tagging': 'everyone', // everyone | followers | none
    'personalisation': 'all', // all | limited | none
    'precise_location': false,
    'filter_messages': true,
    'notif_quality_filter': true,
    'notif_badge': false,
    'notif_likes': true,
    'notif_follows': true,
    'notif_replies': true,
    'notif_mentions': true,
    'notif_moments': true,
    'email_frequency': 'daily', // always | daily | never
    'content_language': 'English',
    'country': '',
    'muted_words': <String>[],
  };

  /// Keys that have their own column on user_settings.
  static const Set<String> _columnKeys = {
    'read_receipts',
    'sensitive_media_display',
    'sensitive_media_mark',
    'live_video',
    'push_notifications',
  };

  /// Keys stored in other columns in a different shape.
  static const Set<String> _mappedKeys = {
    'protected',
    'receive_message_requests',
  };

  final Map<String, Object> _values = Map<String, Object>.from(defaults);
  String? _loadedFor;
  bool _loading = false;

  SupabaseRepository get _repo => SupabaseRepository.instance;

  bool getBool(String key) {
    final value = _values[key];
    if (value is bool) return value;
    final fallback = defaults[key];
    return fallback is bool ? fallback : false;
  }

  String getString(String key) {
    final value = _values[key];
    if (value is String) return value;
    final fallback = defaults[key];
    return fallback is String ? fallback : '';
  }

  List<String> getList(String key) {
    final value = _values[key];
    if (value is List) return value.map((e) => e.toString()).toList();
    return const <String>[];
  }

  /// Kept for the existing switch pages. Same as [getBool].
  bool get(String key) => getBool(key);

  /// Kept for the existing switch pages. Same as [setValue].
  Future<void> set(String key, bool value) => setValue(key, value);

  /// Loads the settings row once for each signed-in account.
  Future<void> ensureLoaded() async {
    final me = _repo.uid;
    if (me == null || _loading || _loadedFor == me) return;
    _loading = true;
    try {
      final row = await _repo.fetchUserSettings();
      final rawPrefs = row['prefs'];
      final prefs = rawPrefs is Map
          ? Map<String, dynamic>.from(rawPrefs)
          : <String, dynamic>{};

      _values
        ..clear()
        ..addAll(defaults);

      for (final key in defaults.keys) {
        final fromColumn = _readColumn(key, row);
        if (fromColumn != null) {
          _values[key] = fromColumn;
          continue;
        }
        final raw = prefs[key];
        if (raw is bool || raw is String) {
          _values[key] = raw as Object;
        } else if (raw is List) {
          _values[key] = raw.map((e) => e.toString()).toList();
        }
      }
      _loadedFor = me;
    } catch (error) {
      debugPrint('settings load failed: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Updates one setting right away, then saves it. Reverts on failure.
  Future<void> setValue(String key, Object value) async {
    final previous = _values[key];
    _values[key] = value;
    notifyListeners();
    try {
      await _repo.upsertUserSettings(_rowFor(key, value));
    } catch (error) {
      debugPrint('settings save failed: $error');
      if (previous == null) {
        _values.remove(key);
      } else {
        _values[key] = previous;
      }
      notifyListeners();
    }
  }

  static Object? _readColumn(String key, Map<String, dynamic> row) {
    switch (key) {
      case 'protected':
        final v = row['account_privacy'];
        return v == null ? null : v == 'protected';
      case 'receive_message_requests':
        final v = row['messages_audience'];
        return v == null ? null : v == 'everyone';
      default:
        if (_columnKeys.contains(key)) {
          final v = row[key];
          return v is bool ? v : null;
        }
        return null;
    }
  }

  /// The user_settings values to save for one changed setting.
  Map<String, dynamic> _rowFor(String key, Object value) {
    switch (key) {
      case 'protected':
        return {'account_privacy': value == true ? 'protected' : 'public'};
      case 'receive_message_requests':
        return {'messages_audience': value == true ? 'everyone' : 'followers'};
      default:
        if (_columnKeys.contains(key)) return {key: value};
        return {'prefs': _prefsJson(key, value)};
    }
  }

  /// All prefs-stored settings, including the changed one. The whole jsonb
  /// value is saved, so nothing is lost.
  Map<String, dynamic> _prefsJson(String key, Object value) {
    final map = <String, dynamic>{};
    for (final entry in _values.entries) {
      if (_columnKeys.contains(entry.key) || _mappedKeys.contains(entry.key)) {
        continue;
      }
      map[entry.key] = entry.value;
    }
    map[key] = value;
    return map;
  }
}

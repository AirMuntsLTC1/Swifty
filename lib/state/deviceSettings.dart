// lib/state/deviceSettings.dart
//
// Settings for this device, shared by every Swifs account on it. They are saved
// with SharedPreferences, so they also work before sign-in.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceSettings extends ChangeNotifier {
  DeviceSettings._();
  static final DeviceSettings instance = DeviceSettings._();

  SharedPreferences? _prefs;

  /// Call once in main() before runApp.
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    notifyListeners();
  }

  bool _bool(String key, bool fallback) => _prefs?.getBool(key) ?? fallback;
  String _string(String key, String fallback) =>
      _prefs?.getString(key) ?? fallback;
  int _int(String key, int fallback) => _prefs?.getInt(key) ?? fallback;

  /// Saves one value (bool, int or String) and notifies listeners.
  Future<void> update(String key, Object value) async {
    final prefs = _prefs;
    if (prefs != null) {
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    }
    notifyListeners();
  }

  // Display and sound.
  /// 'system' | 'light' | 'dark'
  String get darkModeChoice => _string('dark_mode', 'system');
  /// 'dim' | 'lights_out'
  String get darkAppearance => _string('dark_appearance', 'dim');
  bool get mediaPreviews => _bool('media_previews', false);
  bool get soundEffects => _bool('sound_effects', false);
  bool get inAppBrowser => _bool('in_app_browser', false);

  ThemeMode get themeMode {
    switch (darkModeChoice) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  // Data usage.
  bool get dataSaver => _bool('data_saver', true);
  /// 'always' | 'wifi' | 'never'
  String get imageQuality => _string('image_quality', 'always');
  /// 'wifi' | 'always' | 'never'
  String get videoQuality => _string('video_quality', 'wifi');
  /// 'wifi' | 'always' | 'never'
  String get videoAutoplay => _string('video_autoplay', 'wifi');
  bool get syncData => _bool('sync_data', true);
  /// 'hourly' | 'daily' | 'weekly'
  String get syncInterval => _string('sync_interval', 'daily');

  /// Largest image width to decode. Null means full quality.
  int? get imageMaxWidth => dataSaver ? 480 : null;

  // Accessibility.
  bool get pronounceHashtag => _bool('pronounce_hashtag', true);
  bool get composeImageDescriptions =>
      _bool('compose_image_descriptions', false);
  bool get reduceMotion => _bool('reduce_motion', false);

  // Proxy.
  bool get proxyEnabled => _bool('proxy_enabled', false);
  String get proxyHost => _string('proxy_host', '');
  int get proxyPort => _int('proxy_port', 8080);
}





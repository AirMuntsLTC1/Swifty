// lib/main.dart
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:flutter_twitter_clone/helper/app_error.dart';
import 'package:flutter_twitter_clone/helper/proxy_overrides.dart';
import 'package:flutter_twitter_clone/state/badgeState.dart';
import 'package:flutter_twitter_clone/state/deviceSettings.dart';
import 'package:flutter_twitter_clone/state/searchState.dart';
import 'package:flutter_twitter_clone/state/settingsState.dart';
import 'package:flutter_twitter_clone/state/suggestionUserState.dart';
import 'package:flutter_twitter_clone/supabase/screens/auth_gate.dart';
import 'package:flutter_twitter_clone/supabase/supabase_auth_service.dart';
import 'package:flutter_twitter_clone/ui/page/common/locator.dart';
import 'package:flutter_twitter_clone/ui/theme/dark_theme.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';

import 'helper/routes.dart';
import 'state/appState.dart';
import 'state/authState.dart';
import 'state/chats/chatState.dart';
import 'state/feedState.dart';
import 'state/notificationState.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Device settings first: the theme, image size and proxy depend on them.
  await DeviceSettings.instance.load();
  HttpOverrides.global = ProxyHttpOverrides();
  // Supabase: auth, database, realtime and storage.
  await SupabaseAuthService.initialize();
  // Firebase: only used for the device push token (FCM).
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }
  setupDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => AppState()),
        ChangeNotifierProvider<AuthState>(create: (_) => AuthState()),
        ChangeNotifierProvider<FeedState>(create: (_) => FeedState()),
        ChangeNotifierProvider<ChatState>(create: (_) => ChatState()),
        ChangeNotifierProvider<SearchState>(create: (_) => SearchState()),
        ChangeNotifierProvider<NotificationState>(
            create: (_) => NotificationState()),
        ChangeNotifierProvider<SettingsState>(create: (_) => SettingsState()),
        ChangeNotifierProvider<BadgeState>(create: (_) => BadgeState()),
        ChangeNotifierProvider<SuggestionsState>(
            create: (_) => SuggestionsState()),
      ],
      child: AnimatedBuilder(
        animation: DeviceSettings.instance,
        builder: (context, _) {
          final device = DeviceSettings.instance;
          final bodyText = Theme.of(context).textTheme;
          return MaterialApp(
            scaffoldMessengerKey: appMessengerKey,
            title: 'Swifs',
            theme: AppTheme.appTheme.copyWith(
              textTheme: GoogleFonts.mulishTextTheme(bodyText),
            ),
            darkTheme: darkThemeFor(device.darkAppearance),
            themeMode: device.themeMode,
            debugShowCheckedModeBanner: false,
            routes: Routes.route(),
            onGenerateRoute: (settings) => Routes.onGenerateRoute(settings),
            onUnknownRoute: (settings) => Routes.onUnknownRoute(settings),
            home: const SupabaseAuthGate(),
          );
        },
      ),
    );
  }
}

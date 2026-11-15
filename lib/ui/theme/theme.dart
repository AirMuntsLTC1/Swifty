import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
part 'app_icons.dart';
part 'color/light_color.dart';
part 'text_styles.dart';
part 'extention.dart';

class AppTheme {
  static final ThemeData appTheme = ThemeData.light().copyWith(
    scaffoldBackgroundColor: TwitterColor.white,
    brightness: Brightness.light,
    primaryColor: AppColor.primary,
    cardColor: Colors.white,
    unselectedWidgetColor: Colors.grey,
    // White dialogs. Material 3 otherwise tints them pink.
    dialogTheme: const DialogTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    // Soft light-grey separators everywhere (feed, search, settings, lists).
    // Without this, Divider() falls back to a dark default and looks black.
    dividerColor: const Color(0xffEFF3F4),
    dividerTheme: const DividerThemeData(
      color: Color(0xffEFF3F4),
      thickness: 0.6,
      space: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColor.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: TwitterColor.white,
      iconTheme: IconThemeData(
        color: TwitterColor.dodgeBlue,
      ),
      elevation: 0,
      // ignore: deprecated_member_use
    ),
    bottomAppBarTheme: ThemeData.light().bottomAppBarTheme.copyWith(
          color: Colors.white,
          elevation: 0,
        ),
    tabBarTheme: TabBarTheme(
      labelStyle: TextStyles.titleStyle.copyWith(color: TwitterColor.dodgeBlue),
      unselectedLabelColor: AppColor.darkGrey,
      unselectedLabelStyle:
          TextStyles.titleStyle.copyWith(color: AppColor.darkGrey),
      labelColor: TwitterColor.dodgeBlue,
      labelPadding: const EdgeInsets.symmetric(vertical: 12),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: TwitterColor.dodgeBlue,
    ),
    colorScheme: const ColorScheme(
      onPrimary: Colors.white,
      onError: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black,
      error: Colors.red,
      primary: Colors.blue,
      primaryContainer: Colors.blue,
      secondary: AppColor.secondary,
      secondaryContainer: AppColor.darkGrey,
      surface: Colors.white,
      brightness: Brightness.light,
    ),
  );

  static List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(
        blurRadius: 10,
        offset: const Offset(5, 5),
        color: AppTheme.appTheme.colorScheme.secondary,
        spreadRadius: 1)
  ];
  static BoxDecoration softDecoration =
      const BoxDecoration(boxShadow: <BoxShadow>[
    BoxShadow(
        blurRadius: 8,
        offset: Offset(5, 5),
        color: Color(0xffe2e5ed),
        spreadRadius: 5),
    BoxShadow(
        blurRadius: 8,
        offset: Offset(-5, -5),
        color: Color(0xffffffff),
        spreadRadius: 5)
  ], color: Color(0xfff1f3f6));
}

String get description {
  return '';
}







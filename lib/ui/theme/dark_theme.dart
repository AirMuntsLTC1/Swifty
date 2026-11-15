// lib/ui/theme/dark_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_twitter_clone/ui/theme/theme.dart';

/// Dark theme. [appearance] is 'dim' (blue-grey) or 'lights_out' (black).
ThemeData darkThemeFor(String appearance) {
  final lightsOut = appearance == 'lights_out';
  final background =
      lightsOut ? const Color(0xFF000000) : const Color(0xFF15202B);
  final surface = lightsOut ? const Color(0xFF16181C) : const Color(0xFF192734);
  final base = ThemeData.dark();

  return base.copyWith(
    scaffoldBackgroundColor: background,
    cardColor: surface,
    dividerColor: const Color(0xFF38444D),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColor.primary),
    ),
    colorScheme: base.colorScheme.copyWith(
      primary: AppColor.primary,
      surface: background,
    ),
    textTheme: GoogleFonts.mulishTextTheme(base.textTheme),
  );
}

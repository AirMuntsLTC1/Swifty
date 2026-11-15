import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TitleText extends StatelessWidget {
  final String text;
  final double fontSize;
  /// Null means "follow the theme" (black in light mode, white in dark mode).
  final Color? color;
  final FontWeight fontWeight;
  final TextAlign textAlign;
  final TextOverflow overflow;
  const TitleText(
    this.text, {
    Key? key,
    this.fontSize = 18,
    this.color,
    this.fontWeight = FontWeight.w800,
    this.textAlign = TextAlign.left,
    this.overflow = TextOverflow.visible,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.mulish(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
      textAlign: textAlign,
      overflow: overflow,
    );
  }
}





import 'package:flutter/material.dart';

abstract final class Palette {
  static const background = Color(0xFF14111C);
  static const ink = Color(0xFFEFE6D8);
  static const muted = Color(0xFFA99F92);
  static const accent = Color(0xFFE8A95B);
  static const live = Color(0xFF7BD88F);
  static const stone = Color(0xFFC9B79C);
  static const hairline = Color(0x1FEFE6D8);
}

abstract final class TextStyles {
  static const display = TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1, color: Palette.ink);
  static const heading = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Palette.ink);
  static const body = TextStyle(fontSize: 14, color: Palette.ink);
  static const muted = TextStyle(color: Palette.muted);
  static const small = TextStyle(fontSize: 12, color: Palette.muted, height: 1.6);
  static const refrain = TextStyle(color: Palette.muted, fontStyle: FontStyle.italic);
  static const shadow = [Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 2))];
}

ThemeData buildTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Palette.background,
      colorScheme: const ColorScheme.dark(primary: Palette.accent),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF2A2433),
        contentTextStyle: TextStyle(color: Palette.ink),
        behavior: SnackBarBehavior.floating,
      ),
    );

/// Largest text scale the game honours.
const double maxTextScale = 1.2;

/// `MaterialApp.builder` that keeps text scaling within [maxTextScale].
///
/// Flutter on the web derives the text scale from the browser's base font
/// size. Some WebViews, the Pi Browser among them, report one so large that
/// a single letter fills the screen and every word is pushed out of sight.
Widget clampTextScaling(BuildContext context, Widget? child) => MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: child ?? const SizedBox.shrink(),
    );

/// `MaterialApp.builder`: [clampTextScaling] plus sane text-spacing
/// overrides.
///
/// Flutter on the web honours the browser's text-spacing accessibility
/// settings (line height, letter/word/paragraph spacing) by measuring a
/// hidden probe element. Inside the Pi Browser that probe reports a line
/// height 625 times the font size, so every line of text became ~600 times
/// too tall and the whole title card was pushed off screen. Values in a
/// plausible accessibility range are kept; absurd ones are dropped.
Widget safeTypography(BuildContext context, Widget? child) {
  final data = MediaQuery.of(context);
  double? within(double? value, double min, double max) =>
      value != null && value >= min && value <= max ? value : null;
  return MediaQuery.applyTextStyleOverrides(
    lineHeightScaleFactorOverride: within(data.lineHeightScaleFactorOverride, 0.5, 3),
    letterSpacingOverride: within(data.letterSpacingOverride, -5, 20),
    wordSpacingOverride: within(data.wordSpacingOverride, -5, 40),
    paragraphSpacingOverride: within(data.paragraphSpacingOverride, 0, 100),
    child: Builder(builder: (context) => clampTextScaling(context, child)),
  );
}

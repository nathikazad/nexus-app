import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static bool isDark = false;

  static Color get bg =>
      isDark ? const Color(0xff0f1115) : const Color(0xfff6f5f1);
  static Color get panel =>
      isDark ? const Color(0xff15171c) : const Color(0xfffbfaf7);
  static Color get surface => isDark ? const Color(0xff1b1e24) : Colors.white;
  static Color get subtle =>
      isDark ? const Color(0xff20232a) : const Color(0xffeeece6);
  static Color get hover =>
      isDark ? const Color(0xff2a2e37) : const Color(0xffe9e6de);
  static Color get line =>
      isDark ? const Color(0xff2e333d) : const Color(0xffdedbd2);
  static Color get lineStrong =>
      isDark ? const Color(0xff444a56) : const Color(0xffc9c5ba);
  static Color get text =>
      isDark ? const Color(0xfff4f4f5) : const Color(0xff25231f);
  static Color get muted =>
      isDark ? const Color(0xffa1a1aa) : const Color(0xff736f66);
  static Color get faint =>
      isDark ? const Color(0xff71717a) : const Color(0xff9a958b);
  static Color get accent =>
      isDark ? const Color(0xff7ac7b7) : const Color(0xff276b61);
  static Color get accentSoft =>
      isDark ? const Color(0xff1e3431) : const Color(0xffe3efec);
  static Color get blue =>
      isDark ? const Color(0xff8ab4f8) : const Color(0xff365f91);
  static Color get blueSoft =>
      isDark ? const Color(0xff1d2b40) : const Color(0xffe8eef7);
  static Color get amber =>
      isDark ? const Color(0xffe5b567) : const Color(0xff8b6518);
  static Color get amberSoft =>
      isDark ? const Color(0xff3a2f1b) : const Color(0xfff4ead3);
  static Color get red =>
      isDark ? const Color(0xffff8a80) : const Color(0xffa3443f);
}

ThemeData buildAppTheme({bool dark = false}) {
  AppColors.isDark = dark;
  final base = ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: AppColors.bg,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    cardColor: AppColors.surface,
    dividerColor: AppColors.line,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
      fontFamily: 'Inter',
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.panel,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: AppColors.accent),
      ),
      hintStyle: TextStyle(color: AppColors.faint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.text,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        minimumSize: const Size(0, 36),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        minimumSize: const Size(0, 36),
      ),
    ),
  );
}

BoxDecoration panelDecoration({Color? color}) {
  return BoxDecoration(
    color: color ?? AppColors.panel,
    border: Border.all(color: AppColors.line),
    borderRadius: BorderRadius.circular(8),
  );
}

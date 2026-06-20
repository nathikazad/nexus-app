import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const bg = Color(0xfff6f5f1);
  static const panel = Color(0xfffbfaf7);
  static const surface = Colors.white;
  static const subtle = Color(0xffeeece6);
  static const hover = Color(0xffe9e6de);
  static const line = Color(0xffdedbd2);
  static const lineStrong = Color(0xffc9c5ba);
  static const text = Color(0xff25231f);
  static const muted = Color(0xff736f66);
  static const faint = Color(0xff9a958b);
  static const accent = Color(0xff276b61);
  static const accentSoft = Color(0xffe3efec);
  static const blue = Color(0xff365f91);
  static const blueSoft = Color(0xffe8eef7);
  static const amber = Color(0xff8b6518);
  static const amberSoft = Color(0xfff4ead3);
  static const red = Color(0xffa3443f);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
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
    appBarTheme: const AppBarTheme(
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
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
      hintStyle: const TextStyle(color: AppColors.faint),
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
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        minimumSize: const Size(0, 36),
      ),
    ),
  );
}

BoxDecoration panelDecoration({Color color = AppColors.panel}) {
  return BoxDecoration(
    color: color,
    border: Border.all(color: AppColors.line),
    borderRadius: BorderRadius.circular(8),
  );
}

import 'package:flutter/material.dart';

class RecallColors {
  const RecallColors._();

  static const background = Color(0xfff8f8f7);
  static const surface = Colors.white;
  static const ink = Color(0xff18181b);
  static const muted = Color(0xff71717a);
  static const faint = Color(0xffa1a1aa);
  static const line = Color(0xffe4e4e7);
  static const soft = Color(0xfff4f4f5);
  static const violet = Color(0xff7c3aed);
  static const orange = Color(0xffc2410c);
  static const rose = Color(0xffbe123c);
  static const sky = Color(0xff0369a1);
  static const emerald = Color(0xff047857);
}

ThemeData buildRecallTheme() {
  final base = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RecallColors.ink,
      brightness: Brightness.light,
      surface: RecallColors.surface,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: RecallColors.background,
    dividerColor: RecallColors.line,
    textTheme: base.textTheme.apply(
      bodyColor: RecallColors.ink,
      displayColor: RecallColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RecallColors.surface,
      foregroundColor: RecallColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RecallColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: RecallColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: RecallColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: RecallColors.ink),
      ),
    ),
    cardTheme: CardThemeData(
      color: RecallColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: RecallColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RecallColors.ink,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RecallColors.ink,
        side: const BorderSide(color: RecallColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
  );
}

ThemeData buildRecallDarkTheme() {
  const background = Color(0xff101012);
  const surface = Color(0xff18181b);
  const ink = Color(0xfff4f4f5);
  const line = Color(0xff3f3f46);
  const soft = Color(0xff27272a);
  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xffa78bfa),
      brightness: Brightness.dark,
      surface: surface,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: background,
    dividerColor: line,
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: soft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ink),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
  );
}

TextStyle get monoLabel => const TextStyle(
  fontFamily: 'monospace',
  fontSize: 11,
  letterSpacing: 0.8,
  color: RecallColors.faint,
  fontWeight: FontWeight.w500,
);

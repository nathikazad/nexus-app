import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color bg = Color(0xffffffff);
  static const Color panel = Color(0xffffffff);
  static const Color sidebar = Color(0xfffafafa);
  static const Color subtle = Color(0xfff4f4f5);
  static const Color hover = Color(0xffe4e4e7);
  static const Color line = Color(0xffe4e4e7);
  static const Color text = Color(0xff18181b);
  static const Color muted = Color(0xff71717a);
  static const Color faint = Color(0xffa1a1aa);
  static const Color accent = Color(0xff27272a);
  static const Color accentSoft = Color(0xfff4f4f5);
  static const Color blue = Color(0xff3f6ca8);
  static const Color amber = Color(0xff9a6a18);
  static const Color green = Color(0xff3d7c72);
  static const Color red = Color(0xffa6534f);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      surface: AppColors.bg,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    dividerColor: AppColors.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xffd4d4d8)),
      ),
      hintStyle: const TextStyle(color: AppColors.faint),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.panel,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.panel,
      indicatorColor: AppColors.subtle,
    ),
  );
}

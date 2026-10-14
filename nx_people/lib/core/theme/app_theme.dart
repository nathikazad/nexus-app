import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color bg = Color(0xfffaf9f6);
  static const Color panel = Color(0xffffffff);
  static const Color sidebar = Color(0xfffaf9f6);
  static const Color subtle = Color(0xfff5f2eb);
  static const Color hover = Color(0xffeae6db);
  static const Color line = Color(0xffeae6db);
  static const Color lineStrong = Color(0xffd5d1c5);
  static const Color text = Color(0xff2c2b29);
  static const Color muted = Color(0xff5a5854);
  static const Color faint = Color(0xff8b8881);
  static const Color blue = Color(0xff3f6ca8);
  static const Color amber = Color(0xff9a6a18);
  static const Color green = Color(0xff2f5138);
  static const Color red = Color(0xffa6534f);
  static const Color resultHover = Color(0xffeef5f4);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
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
    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.panel,
      surfaceTintColor: Colors.transparent,
    ),
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
        borderSide: const BorderSide(color: AppColors.lineStrong),
      ),
      hintStyle: const TextStyle(color: AppColors.faint),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.panel,
      indicatorColor: AppColors.subtle,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.text,
        foregroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}

/// Editorial headings inspired by the Aura concept; native iOS serif typography.
TextStyle peopleEditorialTitle(double size) => TextStyle(
  fontFamily: 'Georgia',
  fontFamilyFallback: const ['Times New Roman', 'serif'],
  fontSize: size,
  height: 1.18,
  letterSpacing: -.7,
  fontWeight: FontWeight.w400,
  color: AppColors.text,
);

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette aligned with `reference/` Tailwind tokens.
abstract final class AppColors {
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);

  static const Color red600 = Color(0xFFDC2626);

  /// Reference link / header actions (Tailwind sky-600).
  static const Color sky600 = Color(0xFF0284C7);
  static const Color teal100 = Color(0xFFCCFBF1);
  static const Color teal600 = Color(0xFF0D9488);

  static const Color accent = Color(0xFFF97316);
  static const Color accentLight = Color(0xFFFFEDD5);
  static const Color accentHover = Color(0xFFFB923C);

  static const Color sleepBlue = Color(0xFF60A5FA);
  static const Color routineGray = Color(0xFFCBD5E1);
  static const Color exerciseGreen = Color(0xFF22C55E);
  static const Color eatYellow = Color(0xFFFACC15);
  static const Color outdoorsTeal = Color(0xFF14B8A6);

  // Goals (reference goals_tab)
  static const Color goalOnTrack = Color(0xFF0F6E56);
  static const Color goalAtRisk = Color(0xFFBA7517);
  static const Color goalMissed = Color(0xFFA32D2D);
  static const Color dotOk = Color(0xFF1D9E75);
  static const Color dotMiss = Color(0xFFE24B4A);
  static const Color dotPend = Color(0xFFE2E8F0);
  static const Color dotTodayProg = Color(0xFFBA7517);

  // Calendar stacked bars (reference tab-calendar)
  static const Color calPurple = Color(0xFF534AB7);
  static const Color calGreen = Color(0xFF1D9E75);
  static const Color calOrange = Color(0xFFD85A30);
  static const Color calBlue = Color(0xFF185FA5);
  static const Color calOlive = Color(0xFF639922);
  static const Color calMuted = Color(0x4D888780);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.accent,
    surface: Colors.white,
    onSurface: AppColors.slate900,
  );

  final textTheme = GoogleFonts.interTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      backgroundColor: Colors.white,
      elevation: 0,
    ),
    dividerColor: AppColors.slate200,
  );
}

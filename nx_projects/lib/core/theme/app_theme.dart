import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette aligned with `reference/mobile/styles.css` :root tokens.
abstract final class AppColors {
  static const Color bg = Color(0xFF0F1115);
  static const Color panel = Color(0xFF171A21);
  static const Color panel2 = Color(0xFF1D2129);
  static const Color panel3 = Color(0xFF232834);
  static const Color border = Color(0xFF262B36);
  static const Color border2 = Color(0xFF2F3543);
  static const Color text = Color(0xFFE7E9EE);
  static const Color muted = Color(0xFF8A93A6);
  static const Color dim = Color(0xFF5B6475);
  static const Color accent = Color(0xFF6AA3FF);
  static const Color accentSoft = Color(0x1E6AA3FF);
  static const Color ok = Color(0xFF4ADE80);
  static const Color warn = Color(0xFFFBBF24);
  static const Color crit = Color(0xFFF87171);
  static const Color feat = Color(0xFFA7C7FF);
  static const Color bug = Color(0xFFFCA5A5);
  static const Color pNexus = Color(0xFF6AA3FF);
  static const Color pPipe = Color(0xFFF59E0B);
  static const Color pMobile = Color(0xFFC084FC);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    surface: AppColors.panel,
    onSurface: AppColors.text,
    onPrimary: AppColors.bg,
    error: AppColors.crit,
    outline: AppColors.border,
  );

  final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: textTheme.copyWith(
      bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 14, height: 1.45),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: textTheme.bodySmall?.copyWith(fontSize: 14, height: 1.45),
    ),
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: AppColors.panel,
      foregroundColor: AppColors.text,
      elevation: 0,
    ),
    dividerColor: AppColors.border,
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.panel,
      indicatorColor: AppColors.accentSoft,
    ),
  );
}

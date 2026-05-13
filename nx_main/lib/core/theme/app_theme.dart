import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for Nexus Main: gray neutrals, orange accent, Inter typography
/// (aligned with [mobile/nx_main/reference] hardware shell).
abstract final class AppColors {
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray900 = Color(0xFF111827);

  static const orange50 = Color(0xFFFFF7ED);
  static const orange600 = Color(0xFFEA580C);
  static const orange700 = Color(0xFFC2410C);

  static const green500 = Color(0xFF22C55E);
  static const red600 = Color(0xFFDC2626);
}

ThemeData buildNexusMainTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.orange600,
      onPrimary: Colors.white,
      primaryContainer: AppColors.orange50,
      surface: Colors.white,
      onSurface: AppColors.gray900,
      onSurfaceVariant: AppColors.gray500,
      outline: AppColors.gray100,
      error: AppColors.red600,
    ),
    scaffoldBackgroundColor: AppColors.gray50,
    dividerColor: AppColors.gray100,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    headlineLarge:
        GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: -0.5),
    headlineMedium:
        GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: -0.5),
    titleLarge:
        GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: -0.3),
    titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
    bodyLarge: GoogleFonts.inter(color: AppColors.gray600),
    bodyMedium: GoogleFonts.inter(color: AppColors.gray600),
    bodySmall: GoogleFonts.inter(color: AppColors.gray400, fontSize: 12),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.gray900,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        color: AppColors.gray900,
      ),
      surfaceTintColor: Colors.transparent,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      selectedItemColor: AppColors.orange600,
      unselectedItemColor: AppColors.gray400,
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.orange600,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: const CircleBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gray900,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gray900,
        side: const BorderSide(color: AppColors.gray200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.gray50,
      focusColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.orange600, width: 1.5),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.gray500,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.gray100),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.05),
    ),
  );
}

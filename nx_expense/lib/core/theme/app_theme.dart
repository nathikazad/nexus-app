import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens aligned with [mobile/plans/current/reference-design.html]
/// (slate neutrals, teal accent, Inter-like typography).
abstract final class AppColors {
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate900 = Color(0xFF0F172A);

  static const teal500 = Color(0xFF14B8A6);
  static const teal600 = Color(0xFF0D9488);
  static const teal700 = Color(0xFF0F766E);
  static const teal100 = Color(0xFFCCFBF1);

  static const red50 = Color(0xFFFEF2F2);
  static const red100 = Color(0xFFFEE2E2);
  static const red600 = Color(0xFFDC2626);
}

ThemeData buildExpenseTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.teal600,
      onPrimary: Colors.white,
      primaryContainer: AppColors.teal100,
      surface: Colors.white,
      onSurface: AppColors.slate900,
      onSurfaceVariant: AppColors.slate500,
      outline: AppColors.slate200,
      error: AppColors.red600,
    ),
    scaffoldBackgroundColor: AppColors.slate50,
    dividerColor: AppColors.slate100,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    headlineLarge: GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    headlineMedium: GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    titleLarge: GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
    bodyLarge: GoogleFonts.inter(color: AppColors.slate700),
    bodyMedium: GoogleFonts.inter(color: AppColors.slate700),
    bodySmall: GoogleFonts.inter(color: AppColors.slate400, fontSize: 12),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.slate900,
      titleTextStyle: textTheme.titleLarge,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      height: 80,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 10,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.teal600 : AppColors.slate400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.teal600 : AppColors.slate400,
          size: 22,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.teal600,
      foregroundColor: Colors.white,
      elevation: 8,
      shape: const CircleBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.red600,
        side: const BorderSide(color: AppColors.red100, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.slate50,
      focusColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.teal600, width: 1.5),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.slate500,
        letterSpacing: 0.5,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.slate100,
      labelStyle: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.slate600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide.none,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.slate100),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.05),
    ),
  );
}

/// Section title: uppercase slate-400 tracking.
TextStyle sectionTitleStyle(BuildContext context) {
  return GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: AppColors.slate400,
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable brand/status colors and default dark fallback values.
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

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.panel3,
    required this.border,
    required this.border2,
    required this.text,
    required this.muted,
    required this.dim,
    required this.accent,
    required this.accentSoft,
    required this.ok,
    required this.warn,
    required this.crit,
    required this.feat,
    required this.bug,
    required this.pNexus,
    required this.pPipe,
    required this.pMobile,
  });

  final Color bg;
  final Color panel;
  final Color panel2;
  final Color panel3;
  final Color border;
  final Color border2;
  final Color text;
  final Color muted;
  final Color dim;
  final Color accent;
  final Color accentSoft;
  final Color ok;
  final Color warn;
  final Color crit;
  final Color feat;
  final Color bug;
  final Color pNexus;
  final Color pPipe;
  final Color pMobile;

  static const dark = AppPalette(
    bg: AppColors.bg,
    panel: AppColors.panel,
    panel2: AppColors.panel2,
    panel3: AppColors.panel3,
    border: AppColors.border,
    border2: AppColors.border2,
    text: AppColors.text,
    muted: AppColors.muted,
    dim: AppColors.dim,
    accent: AppColors.accent,
    accentSoft: AppColors.accentSoft,
    ok: AppColors.ok,
    warn: AppColors.warn,
    crit: AppColors.crit,
    feat: AppColors.feat,
    bug: AppColors.bug,
    pNexus: AppColors.pNexus,
    pPipe: AppColors.pPipe,
    pMobile: AppColors.pMobile,
  );

  static const light = AppPalette(
    bg: Color(0xFFF6F7F9),
    panel: Color(0xFFFFFFFF),
    panel2: Color(0xFFF0F2F5),
    panel3: Color(0xFFE7EAF0),
    border: Color(0xFFD8DDE6),
    border2: Color(0xFFC6CEDA),
    text: Color(0xFF171A21),
    muted: Color(0xFF5B6475),
    dim: Color(0xFF8892A4),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0x1F2563EB),
    ok: Color(0xFF16A34A),
    warn: Color(0xFFD97706),
    crit: Color(0xFFDC2626),
    feat: Color(0xFF2563EB),
    bug: Color(0xFFDC2626),
    pNexus: Color(0xFF2563EB),
    pPipe: Color(0xFFD97706),
    pMobile: Color(0xFF7C3AED),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? panel,
    Color? panel2,
    Color? panel3,
    Color? border,
    Color? border2,
    Color? text,
    Color? muted,
    Color? dim,
    Color? accent,
    Color? accentSoft,
    Color? ok,
    Color? warn,
    Color? crit,
    Color? feat,
    Color? bug,
    Color? pNexus,
    Color? pPipe,
    Color? pMobile,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      panel: panel ?? this.panel,
      panel2: panel2 ?? this.panel2,
      panel3: panel3 ?? this.panel3,
      border: border ?? this.border,
      border2: border2 ?? this.border2,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      dim: dim ?? this.dim,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      ok: ok ?? this.ok,
      warn: warn ?? this.warn,
      crit: crit ?? this.crit,
      feat: feat ?? this.feat,
      bug: bug ?? this.bug,
      pNexus: pNexus ?? this.pNexus,
      pPipe: pPipe ?? this.pPipe,
      pMobile: pMobile ?? this.pMobile,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panel2: Color.lerp(panel2, other.panel2, t)!,
      panel3: Color.lerp(panel3, other.panel3, t)!,
      border: Color.lerp(border, other.border, t)!,
      border2: Color.lerp(border2, other.border2, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      dim: Color.lerp(dim, other.dim, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      crit: Color.lerp(crit, other.crit, t)!,
      feat: Color.lerp(feat, other.feat, t)!,
      bug: Color.lerp(bug, other.bug, t)!,
      pNexus: Color.lerp(pNexus, other.pNexus, t)!,
      pPipe: Color.lerp(pPipe, other.pPipe, t)!,
      pMobile: Color.lerp(pMobile, other.pMobile, t)!,
    );
  }
}

extension AppThemeColors on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}

const _appThemeModePreferenceKey = 'nx_projects.theme_mode';

var _appThemeModeMemory = ThemeMode.dark;

Future<void> initializeAppThemeMode() async {
  try {
    final saved = await SharedPreferencesAsync().getString(
      _appThemeModePreferenceKey,
    );
    _appThemeModeMemory = _decodeThemeMode(saved) ?? ThemeMode.dark;
  } catch (_) {
    _appThemeModeMemory = ThemeMode.dark;
  }
}

ThemeMode? _decodeThemeMode(String? value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => null,
  };
}

String _encodeThemeMode(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

Future<void> _persistThemeMode(ThemeMode mode) async {
  try {
    await SharedPreferencesAsync().setString(
      _appThemeModePreferenceKey,
      _encodeThemeMode(mode),
    );
  } catch (_) {
    // Persistence failure should not block an in-session theme change.
  }
}

class AppThemeMode extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => _appThemeModeMemory;

  void toggle() {
    set(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  void set(ThemeMode mode) {
    _appThemeModeMemory = mode;
    state = mode;
    unawaited(_persistThemeMode(mode));
  }
}

final appThemeModeProvider = NotifierProvider<AppThemeMode, ThemeMode>(
  AppThemeMode.new,
  name: 'appThemeModeProvider',
);

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final palette = dark ? AppPalette.dark : AppPalette.light;
  final scheme = dark
      ? ColorScheme.dark(
          primary: palette.accent,
          surface: palette.panel,
          onSurface: palette.text,
          onPrimary: palette.bg,
          error: palette.crit,
          outline: palette.border,
        )
      : ColorScheme.light(
          primary: palette.accent,
          surface: palette.panel,
          onSurface: palette.text,
          onPrimary: palette.panel,
          error: palette.crit,
          outline: palette.border,
        );

  final base = dark ? ThemeData.dark() : ThemeData.light();
  final textTheme = GoogleFonts.interTextTheme(
    base.textTheme,
  ).apply(bodyColor: palette.text, displayColor: palette.text);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    extensions: <ThemeExtension<dynamic>>[palette],
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    textTheme: textTheme.copyWith(
      bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 14, height: 1.45),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: textTheme.bodySmall?.copyWith(fontSize: 14, height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      backgroundColor: palette.panel,
      foregroundColor: palette.text,
      elevation: 0,
    ),
    dividerColor: palette.border,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.panel,
      indicatorColor: palette.accentSoft,
    ),
  );
}

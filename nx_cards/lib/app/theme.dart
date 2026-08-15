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

@immutable
class RecallPalette extends ThemeExtension<RecallPalette> {
  const RecallPalette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.soft,
  });

  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color line;
  final Color soft;

  static RecallPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<RecallPalette>() ??
        (theme.brightness == Brightness.dark ? _darkPalette : _lightPalette);
  }

  @override
  RecallPalette copyWith({
    Color? background,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? faint,
    Color? line,
    Color? soft,
  }) => RecallPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    faint: faint ?? this.faint,
    line: line ?? this.line,
    soft: soft ?? this.soft,
  );

  @override
  RecallPalette lerp(covariant RecallPalette? other, double t) {
    if (other == null) return this;
    return RecallPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      line: Color.lerp(line, other.line, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
    );
  }
}

const _lightPalette = RecallPalette(
  background: RecallColors.background,
  surface: RecallColors.surface,
  ink: RecallColors.ink,
  muted: RecallColors.muted,
  faint: RecallColors.faint,
  line: RecallColors.line,
  soft: RecallColors.soft,
);

const _darkPalette = RecallPalette(
  background: Color(0xff101012),
  surface: Color(0xff18181b),
  ink: Color(0xfff4f4f5),
  muted: Color(0xffa1a1aa),
  faint: Color(0xff71717a),
  line: Color(0xff3f3f46),
  soft: Color(0xff27272a),
);

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
    extensions: const [_lightPalette],
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
    extensions: const [_darkPalette],
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

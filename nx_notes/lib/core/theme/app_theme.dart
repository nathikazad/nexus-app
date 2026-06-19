import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDarkModeNotifier extends Notifier<bool> with WidgetsBindingObserver {
  bool _followsSystem = true;
  bool _isObservingSystemBrightness = false;

  @override
  bool build() {
    if (!_isObservingSystemBrightness) {
      WidgetsBinding.instance.addObserver(this);
      _isObservingSystemBrightness = true;
      ref.onDispose(() {
        WidgetsBinding.instance.removeObserver(this);
      });
    }
    return _systemPrefersDark;
  }

  @override
  void didChangePlatformBrightness() {
    if (_followsSystem) {
      state = _systemPrefersDark;
    }
  }

  void toggle() {
    _followsSystem = false;
    state = !state;
  }

  bool get _systemPrefersDark {
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }
}

final appDarkModeProvider = NotifierProvider<AppDarkModeNotifier, bool>(
  AppDarkModeNotifier.new,
);

class AppColors {
  static bool isDark = true;

  static Color get bg => isDark ? const Color(0xff0f1115) : Colors.white;
  static Color get panel => isDark ? const Color(0xff15171c) : Colors.white;
  static Color get sidebar =>
      isDark ? const Color(0xff111318) : const Color(0xfffafafa);
  static Color get subtle =>
      isDark ? const Color(0xff20232a) : const Color(0xfff4f4f5);
  static Color get hover =>
      isDark ? const Color(0xff2a2e37) : const Color(0xffe4e4e7);
  static Color get line =>
      isDark ? const Color(0xff2e333d) : const Color(0xffe4e4e7);
  static Color get text =>
      isDark ? const Color(0xfff4f4f5) : const Color(0xff18181b);
  static Color get editorText =>
      isDark ? const Color(0xffd4d4d8) : const Color(0xff3f3f46);
  static Color get muted =>
      isDark ? const Color(0xffa1a1aa) : const Color(0xff71717a);
  static Color get faint =>
      isDark ? const Color(0xff71717a) : const Color(0xffa1a1aa);
  static Color get accent =>
      isDark ? const Color(0xffe4e4e7) : const Color(0xff27272a);
  static Color get accentSoft =>
      isDark ? const Color(0xff242832) : const Color(0xfff4f4f5);
  static Color get blue =>
      isDark ? const Color(0xff8ab4f8) : const Color(0xff3f6ca8);
  static Color get amber =>
      isDark ? const Color(0xffe5b567) : const Color(0xff9a6a18);
  static Color get green =>
      isDark ? const Color(0xff7ac7b7) : const Color(0xff3d7c72);
  static Color get red =>
      isDark ? const Color(0xffff8a80) : const Color(0xffa6534f);
  static Color get floating =>
      isDark ? const Color(0xff09090b) : const Color(0xff18181b);
  static Color get onFloating => Colors.white;
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    brightness: AppColors.isDark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: AppColors.isDark ? Brightness.dark : Brightness.light,
      surface: AppColors.bg,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    canvasColor: AppColors.bg,
    cardColor: AppColors.panel,
    dividerColor: AppColors.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: AppColors.hover),
      ),
      hintStyle: TextStyle(color: AppColors.faint),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.panel,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.panel,
      indicatorColor: AppColors.subtle,
    ),
  );
}

class AppThemeToggleButton extends ConsumerWidget {
  const AppThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appDarkModeProvider);
    return IconButton(
      tooltip: isDark ? 'Light mode' : 'Dark mode',
      onPressed: () {
        ref.read(appDarkModeProvider.notifier).toggle();
      },
      style: IconButton.styleFrom(
        minimumSize: const Size.square(34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 19,
        color: AppColors.muted,
      ),
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    );
  }
}

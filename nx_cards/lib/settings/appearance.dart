import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppAppearance { system, light, dark }

extension AppAppearanceThemeMode on AppAppearance {
  ThemeMode get themeMode => switch (this) {
    AppAppearance.system => ThemeMode.system,
    AppAppearance.light => ThemeMode.light,
    AppAppearance.dark => ThemeMode.dark,
  };
}

class AppearanceStore {
  static const _key = 'nx_cards.appearance.v1';

  Future<AppAppearance> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_key);
    return AppAppearance.values
            .where((value) => value.name == saved)
            .firstOrNull ??
        AppAppearance.system;
  }

  Future<void> save(AppAppearance appearance) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, appearance.name);
  }
}

final appearanceStoreProvider = Provider<AppearanceStore>(
  (ref) => AppearanceStore(),
);

class AppearanceController extends AsyncNotifier<AppAppearance> {
  @override
  Future<AppAppearance> build() => ref.watch(appearanceStoreProvider).load();

  Future<void> setAppearance(AppAppearance appearance) async {
    state = AsyncData(appearance);
    await ref.read(appearanceStoreProvider).save(appearance);
  }
}

final appearanceProvider =
    AsyncNotifierProvider<AppearanceController, AppAppearance>(
      AppearanceController.new,
    );

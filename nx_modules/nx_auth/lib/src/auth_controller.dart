import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_ping.dart';
import 'backend_presets.dart';
import 'oidc_service.dart';
import 'user.dart';

final retainAuthSessionWhenOfflineProvider = Provider<bool>((ref) => false);

/// Stable identifier used to select this installed app's native OIDC client.
final nexusClientAppIdProvider = Provider<String>((ref) => 'nx_mobile');

class AuthController extends AsyncNotifier<User?> {
  AuthController({
    this.initialDelay = const Duration(seconds: 1),
    this.skipBackendPing = false,
  });

  final Duration initialDelay;
  final bool skipBackendPing;

  static Future<void> _clearSessionPrefs(SharedPreferences prefs) async {
    await prefs.remove(PrefsKeys.userId);
    await prefs.remove(PrefsKeys.endpoint);
    await prefs.remove(PrefsKeys.backendPreset);
    await prefs.remove(PrefsKeys.sockWsUrl);
  }

  @override
  Future<User?> build() async {
    if (initialDelay > Duration.zero) await Future.delayed(initialDelay);
    print('[AuthController] build() - Initializing auth state');

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(PrefsKeys.userId);
      final presetKey = prefs.getString(PrefsKeys.backendPreset);
      BackendPreset? preset = BackendPreset.fromKey(presetKey);

      if (userId != null &&
          userId.isNotEmpty &&
          preset == null &&
          prefs.getString(PrefsKeys.endpoint) != null) {
        preset = BackendPreset.defaultPreset;
        final urls = resolve(preset);
        await prefs.setString(PrefsKeys.backendPreset, preset.key);
        await prefs.setString(PrefsKeys.endpoint, urls.graphqlHttp);
        await prefs.setString(PrefsKeys.sockWsUrl, urls.sockWs);
        print('[AuthController] Migrated legacy prefs to preset=${preset.key}');
      }

      if (preset != null && preset.requiresOidc) {
        print('[AuthController] Restoring OIDC session for ${preset.key}');
        final identity = await nexusOidcService.restore(
          preset,
          ref.read(nexusClientAppIdProvider),
        );
        if (identity == null) {
          await _clearSessionPrefs(prefs);
          return null;
        }
        await prefs.setString(PrefsKeys.userId, identity.userId);
        return User(userId: identity.userId, preset: preset);
      }

      if (userId != null && userId.isNotEmpty && preset != null) {
        print(
          '[AuthController] Found saved credentials: userId=$userId preset=${preset.key}',
        );
        if (!skipBackendPing) {
          try {
            final urls = resolve(preset);
            print('[AuthController] restore ping → ${urls.graphqlHttp}');
            await pingGraphqlBackend(
              graphqlHttpUrl: urls.graphqlHttp,
              userId: userId,
            );
          } catch (e) {
            print('[AuthController] restore ping failed: $e');
            if (!ref.read(retainAuthSessionWhenOfflineProvider)) {
              print('[AuthController] clearing session → login required');
              await _clearSessionPrefs(prefs);
              return null;
            }
            print('[AuthController] keeping saved session for offline access');
          }
        }
        return User(userId: userId, preset: preset);
      }

      print('[AuthController] No saved credentials found');
      return null;
    } catch (e) {
      print('[AuthController] Error loading saved credentials: $e');
      return null;
    }
  }

  Future<String?> login(String userId, BackendPreset preset) async {
    print('[AuthController] login() - user: $userId preset: ${preset.key}');
    state = const AsyncValue.loading();

    try {
      if (userId.isEmpty && !preset.requiresOidc) {
        throw Exception('User ID is required');
      }
      final urls = resolve(preset);
      var resolvedUserId = userId;
      if (preset.requiresOidc) {
        final identity = await nexusOidcService.signIn(
          preset,
          ref.read(nexusClientAppIdProvider),
        );
        resolvedUserId = identity.userId;
      } else if (!skipBackendPing) {
        await pingGraphqlBackend(
          graphqlHttpUrl: urls.graphqlHttp,
          userId: userId,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.userId, resolvedUserId);
      await prefs.setString(PrefsKeys.endpoint, urls.graphqlHttp);
      await prefs.setString(PrefsKeys.backendPreset, preset.key);
      await prefs.setString(PrefsKeys.sockWsUrl, urls.sockWs);

      final user = User(userId: resolvedUserId, preset: preset);
      state = AsyncValue.data(user);
      print('[AuthController] Login successful');
      return null;
    } catch (e, stackTrace) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('[AuthController] Login error: $errorMessage');
      state = AsyncValue.error(e, stackTrace);
      return errorMessage;
    }
  }

  Future<void> logout() async {
    print('[AuthController] logout() - Logging out user');
    final currentUser = state.value;
    state = const AsyncValue.loading();
    try {
      if (currentUser?.preset.requiresOidc ?? false) {
        await nexusOidcService.logout();
      }
      final prefs = await SharedPreferences.getInstance();
      await _clearSessionPrefs(prefs);
      state = const AsyncValue.data(null);
      print('[AuthController] Logout successful');
    } catch (e, stackTrace) {
      print('[AuthController] Logout error: $e');
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
  name: 'authProvider',
);

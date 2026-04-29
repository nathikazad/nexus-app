import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/backend_presets.dart';
import 'backend_ping.dart';
import 'user.dart';

/// Default domain ids for prefs migration (single-user dev / legacy installs).
const int kDefaultPersonalDomainId = 1;
const int kDefaultHomeDomainId = 1;

/// AuthController manages user authentication state.
/// Loads saved credentials from SharedPreferences on initialization.
class AuthController extends AsyncNotifier<User?> {
  AuthController({
    this.initialDelay = const Duration(seconds: 1),
    this.skipBackendPing = false,
  });

  /// Artificial delay before reading prefs (tests use [Duration.zero]).
  final Duration initialDelay;

  /// When true, [login] and session restore skip [pingGraphqlBackend] (tests).
  final bool skipBackendPing;

  static Future<void> _clearSessionPrefs(SharedPreferences prefs) async {
    await prefs.remove(PrefsKeys.userId);
    await prefs.remove(PrefsKeys.personalDomainId);
    await prefs.remove(PrefsKeys.homeDomainId);
    await prefs.remove(PrefsKeys.endpoint);
    await prefs.remove(PrefsKeys.backendPreset);
    await prefs.remove(PrefsKeys.sockWsUrl);
  }

  @override
  Future<User?> build() async {
    if (initialDelay > Duration.zero) {
      await Future.delayed(initialDelay);
    }
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

      int? personalDomainId = prefs.getInt(PrefsKeys.personalDomainId);
      int? homeDomainId = prefs.getInt(PrefsKeys.homeDomainId);
      if (userId != null &&
          userId.isNotEmpty &&
          preset != null &&
          (personalDomainId == null || homeDomainId == null)) {
        personalDomainId ??= kDefaultPersonalDomainId;
        homeDomainId ??= kDefaultHomeDomainId;
        await prefs.setInt(PrefsKeys.personalDomainId, personalDomainId);
        await prefs.setInt(PrefsKeys.homeDomainId, homeDomainId);
        print(
          '[AuthController] Migrated missing domain prefs → '
          'personal=$personalDomainId home=$homeDomainId',
        );
      }

      if (userId != null &&
          userId.isNotEmpty &&
          preset != null &&
          personalDomainId != null &&
          homeDomainId != null) {
        print(
          '[AuthController] Found saved credentials: userId=$userId, '
          'personalDomain=$personalDomainId homeDomain=$homeDomainId preset=${preset.key}',
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
            print('[AuthController] clearing session → login required');
            await _clearSessionPrefs(prefs);
            return null;
          }
        }
        return User(
          userId: userId,
          personalDomainId: personalDomainId,
          homeDomainId: homeDomainId,
          preset: preset,
        );
      } else {
        print('[AuthController] No saved credentials found');
        return null;
      }
    } catch (e) {
      print('[AuthController] Error loading saved credentials: $e');
      return null;
    }
  }

  /// Logs in with [userId], [preset], and domain ids. Persists to SharedPreferences.
  /// Returns null if login was successful, error message String otherwise.
  Future<String?> login(
    String userId,
    BackendPreset preset,
    int personalDomainId,
    int homeDomainId,
  ) async {
    print(
      '[AuthController] login() - user: $userId preset: ${preset.key} '
      'personalDomain=$personalDomainId homeDomain=$homeDomainId',
    );
    state = const AsyncValue.loading();

    try {
      if (userId.isEmpty) {
        throw Exception('User ID is required');
      }
      if (personalDomainId <= 0 || homeDomainId <= 0) {
        throw Exception('Personal and home domain IDs must be positive integers');
      }

      final urls = resolve(preset);
      if (!skipBackendPing) {
        await pingGraphqlBackend(
          graphqlHttpUrl: urls.graphqlHttp,
          userId: userId,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.userId, userId);
      await prefs.setInt(PrefsKeys.personalDomainId, personalDomainId);
      await prefs.setInt(PrefsKeys.homeDomainId, homeDomainId);
      await prefs.setString(PrefsKeys.endpoint, urls.graphqlHttp);
      await prefs.setString(PrefsKeys.backendPreset, preset.key);
      await prefs.setString(PrefsKeys.sockWsUrl, urls.sockWs);

      final user = User(
        userId: userId,
        personalDomainId: personalDomainId,
        homeDomainId: homeDomainId,
        preset: preset,
      );
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

  /// Clears SharedPreferences and updates state to null.
  Future<void> logout() async {
    print('[AuthController] logout() - Logging out user');
    state = const AsyncValue.loading();
    try {
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

/// Provider for the AuthController.
final authProvider = AsyncNotifierProvider<AuthController, User?>((() {
  return AuthController();
}), name: 'authProvider');

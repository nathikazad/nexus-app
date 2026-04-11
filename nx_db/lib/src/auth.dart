import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_presets.dart';

/// User model: [preset] drives all resolved URLs via [resolve].
class User {
  final String userId;
  final BackendPreset preset;

  User({required this.userId, required this.preset});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          preset == other.preset;

  @override
  int get hashCode => userId.hashCode ^ preset.hashCode;
}

/// AuthController manages user authentication state.
/// Loads saved credentials from SharedPreferences on initialization.
class AuthController extends AsyncNotifier<User?> {
  AuthController({this.initialDelay = const Duration(seconds: 1)});

  /// Artificial delay before reading prefs (tests use [Duration.zero]).
  final Duration initialDelay;

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

      // Migration: old installs had userId + endpoint but no preset key
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

      if (userId != null &&
          userId.isNotEmpty &&
          preset != null) {
        print('[AuthController] Found saved credentials: userId=$userId, preset=${preset.key}');
        return User(userId: userId, preset: preset);
      } else {
        print('[AuthController] No saved credentials found');
        return null;
      }
    } catch (e) {
      print('[AuthController] Error loading saved credentials: $e');
      return null;
    }
  }

  /// Logs in with [userId] and [preset]. Persists resolved URLs to SharedPreferences.
  /// Returns null if login was successful, error message String otherwise.
  Future<String?> login(String userId, BackendPreset preset) async {
    print('[AuthController] login() - Logging in user: $userId, preset: ${preset.key}');
    state = const AsyncValue.loading();

    try {
      if (userId.isEmpty) {
        throw Exception('User ID is required');
      }

      final urls = resolve(preset);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.userId, userId);
      await prefs.setString(PrefsKeys.endpoint, urls.graphqlHttp);
      await prefs.setString(PrefsKeys.backendPreset, preset.key);
      await prefs.setString(PrefsKeys.sockWsUrl, urls.sockWs);

      final user = User(userId: userId, preset: preset);
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
      await prefs.remove(PrefsKeys.userId);
      await prefs.remove(PrefsKeys.endpoint);
      await prefs.remove(PrefsKeys.backendPreset);
      await prefs.remove(PrefsKeys.sockWsUrl);

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

/// Current user's ID, or null if not logged in.
final userIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.value?.userId;
}, name: 'userIdProvider');

/// Resolved GraphQL HTTP endpoint from the current preset, or null.
final endpointProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return null;
  return resolve(user.preset).graphqlHttp;
}, name: 'endpointProvider');

/// Resolved sock WebSocket URL from the current preset, or null.
final sockWsUrlProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return null;
  return resolve(user.preset).sockWs;
}, name: 'sockWsUrlProvider');

/// Resolved image HTTP base URL from the current preset, or null.
final imageBaseUrlProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return null;
  return resolve(user.preset).imageHttp;
}, name: 'imageBaseUrlProvider');

/// AppStatus enum representing the three possible states of the app.
enum AppStatus {
  initializing,
  authenticated,
  unauthenticated,
}

/// Stable status that prevents router flicker.
final appStatusProvider = Provider<AppStatus>((ref) {
  final authState = ref.watch(authProvider);

  return authState.when(
    data: (user) => user == null ? AppStatus.unauthenticated : AppStatus.authenticated,
    loading: () => AppStatus.initializing,
    error: (_, __) => AppStatus.unauthenticated,
  );
}, name: 'appStatusProvider');

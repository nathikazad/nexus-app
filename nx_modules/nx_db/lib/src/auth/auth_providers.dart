import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/backend_presets.dart';
import 'auth_controller.dart';

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
    data: (user) =>
        user == null ? AppStatus.unauthenticated : AppStatus.authenticated,
    loading: () => AppStatus.initializing,
    error: (_, __) => AppStatus.unauthenticated,
  );
}, name: 'appStatusProvider');

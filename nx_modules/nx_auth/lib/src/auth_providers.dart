import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'authenticated_http_client.dart';
import 'backend_presets.dart';
import 'oidc_service.dart';

final userIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).value?.userId;
}, name: 'userIdProvider');

final endpointProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).value;
  return user == null ? null : resolve(user.preset).graphqlHttp;
}, name: 'endpointProvider');

final sockWsUrlProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).value;
  return user == null ? null : resolve(user.preset).sockWs;
}, name: 'sockWsUrlProvider');

final imageBaseUrlProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).value;
  return user == null ? null : resolve(user.preset).imageHttp;
}, name: 'imageBaseUrlProvider');

final nexusHttpClientProvider = Provider<NexusAuthenticatedClient?>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return null;
  final client = NexusAuthenticatedClient(
    preset: user.preset,
    userId: user.userId,
  );
  ref.onDispose(client.close);
  return client;
}, name: 'nexusHttpClientProvider');

/// Current identity headers for APIs that cannot accept an authenticated HTTP
/// client, such as Flutter's network image provider.
final nexusRequestHeadersProvider = FutureProvider<Map<String, String>>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return Future.value(const {});
  return nexusAuthHeaders(user.preset, user.userId);
}, name: 'nexusRequestHeadersProvider');

enum AppStatus { initializing, authenticated, unauthenticated }

final appStatusProvider = Provider<AppStatus>((ref) {
  return ref
      .watch(authProvider)
      .when(
        data: (user) =>
            user == null ? AppStatus.unauthenticated : AppStatus.authenticated,
        loading: () => AppStatus.initializing,
        error: (_, __) => AppStatus.unauthenticated,
      );
}, name: 'appStatusProvider');

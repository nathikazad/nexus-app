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
  if (user == null || user.domainId == null) return null;
  final client = NexusAuthenticatedClient(
    preset: user.preset,
    userId: user.userId,
    domainId: user.requiredDomainId,
  );
  ref.onDispose(client.close);
  return client;
}, name: 'nexusHttpClientProvider');

/// Current identity headers for APIs that cannot accept an authenticated HTTP
/// client, such as Flutter's network image provider.
final nexusRequestHeadersProvider = FutureProvider<Map<String, String>>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return Future.value(const {});
  return nexusAuthHeaders(user.preset, user.userId).then(
    (headers) => {
      ...headers,
      if (user.domainId != null) 'x-nexus-domain-id': '${user.domainId}',
    },
  );
}, name: 'nexusRequestHeadersProvider');

enum AppStatus { initializing, selectingDomain, authenticated, unauthenticated }

final appStatusProvider = Provider<AppStatus>((ref) {
  return ref
      .watch(authProvider)
      .when(
        data: (user) => user == null
            ? AppStatus.unauthenticated
            : user.domainId == null
            ? AppStatus.selectingDomain
            : AppStatus.authenticated,
        loading: () => AppStatus.initializing,
        error: (_, __) => AppStatus.unauthenticated,
      );
}, name: 'appStatusProvider');

final domainReadyProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).value?.domainId != null,
);

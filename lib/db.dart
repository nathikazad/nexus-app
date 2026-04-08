import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'auth.dart';
import 'backend_presets.dart';
import 'cf_access.dart';

class GraphQLConfig {
  static String get defaultEndpoint =>
      resolve(BackendPreset.defaultPreset).graphqlHttp;
  static const String defaultUserId = '1';
}

GraphQLClient createClient(String endpoint, String userId) {
  // Upgrade saved http:// endpoints to https:// for Cloudflare tunnel hostnames
  var ep = endpoint;
  if (CfAccess.endpointNeedsCfAccess(ep) && ep.startsWith('http://')) {
    ep = ep.replaceFirst('http://', 'https://');
  }
  final attachCf = CfAccess.shouldAttachHeaders(ep);
  final cf = attachCf ? CfAccess.headers : const <String, String>{};

  final httpLink = HttpLink(
    ep,
    defaultHeaders: {
      'x-user-id': userId,
      ...cf,
    },
  );
  
  // Extract WebSocket URL (replace http:// with ws://, https:// with wss://)
  final wsUrl = ep
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://');
  
  // Create WebSocket link for subscriptions
  final wsLink = WebSocketLink(
    wsUrl,
    config: SocketClientConfig(
      autoReconnect: true,
      inactivityTimeout: const Duration(seconds: 30),
      initialPayload: {'x-user-id': userId},
      headers: attachCf ? cf : null,
    ),
  );
  
  // Split link: subscriptions go to WebSocket, everything else to HTTP
  final link = Link.split(
    (request) => request.isSubscription,
    wsLink,
    httpLink,
  );
  
  return GraphQLClient(
    link: link,
    cache: GraphQLCache(),
  );
}

final graphqlClientProvider = Provider<GraphQLClient>((ref) {
  final userId = ref.watch(userIdProvider);
  final endpoint = ref.watch(endpointProvider);
  
  // Only create client when both userId and endpoint are available
  if (userId == null || endpoint == null) {
    // Return a dummy client if not authenticated (will be recreated when auth completes)
    return createClient(GraphQLConfig.defaultEndpoint, GraphQLConfig.defaultUserId);
  }
  
  // Create a new client only when userId or endpoint changes
  // This prevents unnecessary client recreation
  return createClient(endpoint, userId);
}, name: 'graphqlClientProvider');


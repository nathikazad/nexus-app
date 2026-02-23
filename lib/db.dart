import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'auth.dart';

class GraphQLConfig {
  static String get defaultEndpoint => kDebugMode 
      ? 'http://10.0.0.95:5001/graphql'
      : 'http://192.168.0.44:5001/graphql';
  static const String defaultUserId = '1';
}

GraphQLClient createClient(String endpoint, String userId) {
  final httpLink = HttpLink(
    endpoint,
    defaultHeaders: {
      'x-user-id': userId,
    },
  );
  
  // Extract WebSocket URL (replace http:// with ws://, https:// with wss://)
  final wsUrl = endpoint
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://');
  
  // Create WebSocket link for subscriptions
  final wsLink = WebSocketLink(
    wsUrl,
    config: SocketClientConfig(
      autoReconnect: true,
      inactivityTimeout: const Duration(seconds: 30),
      initialPayload: {'x-user-id': userId},
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


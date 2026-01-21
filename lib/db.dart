import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'auth.dart';

class GraphQLConfig {
  static const String defaultEndpoint = 'http://192.168.0.44:5001/graphql';
  static const String defaultUserId = '1';
}

GraphQLClient createClient(String endpoint, String userId) {
  final httpLink = HttpLink(
    endpoint,
    defaultHeaders: {
      'x-user-id': userId,
    },
  );
  
  return GraphQLClient(
    link: httpLink,
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


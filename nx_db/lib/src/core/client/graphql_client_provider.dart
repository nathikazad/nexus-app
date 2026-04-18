import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../auth/auth_providers.dart';
import 'graphql_client.dart';

final graphqlClientProvider = Provider<GraphQLClient>((ref) {
  final userId = ref.watch(userIdProvider);
  final endpoint = ref.watch(endpointProvider);

  if (userId == null || endpoint == null) {
    return createClient(GraphQLConfig.defaultEndpoint, GraphQLConfig.defaultUserId);
  }

  return createClient(endpoint, userId);
}, name: 'graphqlClientProvider');

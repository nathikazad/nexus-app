import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../auth/auth_providers.dart';
import 'graphql_client.dart';

final dbAuditSourceKindProvider = Provider<String>(
  (ref) => 'nx_mobile',
  name: 'dbAuditSourceKindProvider',
);

final graphqlClientProvider = Provider<GraphQLClient>((ref) {
  final userId = ref.watch(userIdProvider);
  final endpoint = ref.watch(endpointProvider);
  final auditSourceKind = ref.watch(dbAuditSourceKindProvider);

  if (userId == null || endpoint == null) {
    return createClient(
      GraphQLConfig.defaultEndpoint,
      GraphQLConfig.defaultUserId,
      auditSourceKind: auditSourceKind,
    );
  }

  return createClient(endpoint, userId, auditSourceKind: auditSourceKind);
}, name: 'graphqlClientProvider');

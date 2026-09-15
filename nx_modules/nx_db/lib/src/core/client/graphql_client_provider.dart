import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_auth/nx_auth.dart';

import 'graphql_client.dart';

final dbAuditSourceKindProvider = Provider<String>(
  (ref) => 'nx_mobile',
  name: 'dbAuditSourceKindProvider',
);

final graphqlClientProvider = Provider<GraphQLClient>((ref) {
  final userId = ref.watch(userIdProvider);
  final endpoint = ref.watch(endpointProvider);
  final auditSourceKind = ref.watch(dbAuditSourceKindProvider);
  final user = ref.watch(authProvider).value;

  if (userId == null || endpoint == null || user?.domainId == null) {
    throw StateError('A selected domain is required');
  }

  final client = createClient(
    endpoint,
    userId,
    auditSourceKind: auditSourceKind,
    preset: user!.preset,
    domainId: user.requiredDomainId,
  );
  ref.onDispose(() => client.link.dispose());
  return client;
}, name: 'graphqlClientProvider');

@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:test/test.dart' show Tags;

import 'package:nx_db/auth.dart';
import 'package:nx_db/internal.dart';
import 'package:nx_db/kgql.dart';

/// Set `RUN_NX_DB_INTEGRATION=true` to run live GraphQL tests against a running PGDB.
///
/// Targets **localhost PGDB** by default: [`kIntegrationTestBackendUrls.graphqlHttp`]
/// (same seed data story as [`servers/pgdb/docs/llm-reference/seed-data.md`](../../../../servers/pgdb/docs/llm-reference/seed-data.md),
/// typically `user_id=1`). The app [`BackendPreset.laptop`](../../lib/src/backend_presets.dart) uses LAN `10.0.0.90`.
///
/// Optional overrides:
/// - `NX_DB_INTEGRATION_GRAPHQL_HTTP` — full GraphQL URL if not using localhost.
/// - `NX_DB_INTEGRATION_USER_ID` — `x-user-id` (default `1`).
bool get _runIntegration => Platform.environment['RUN_NX_DB_INTEGRATION'] == 'true';

GraphQLClient _integrationClient() {
  final fromEnv = Platform.environment['NX_DB_INTEGRATION_GRAPHQL_HTTP'];
  final graphqlHttp = (fromEnv != null && fromEnv.isNotEmpty)
      ? fromEnv
      : kIntegrationTestBackendUrls.graphqlHttp;
  final userId = Platform.environment['NX_DB_INTEGRATION_USER_ID'] ?? '1';
  return createClient(graphqlHttp, userId);
}

void main() {
  group('IN13 integration (RUN_NX_DB_INTEGRATION=true, localhost PGDB)', () {
    late GraphQLClient client;

    setUpAll(() {
      client = _integrationClient();
    });

    test('IN13.1 live getKgqlModelType parses', () async {
      final result = await client.query(
        QueryOptions(
          document: gql(getAllModelTypesQuery),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      expect(result.hasException, isFalse, reason: '${result.exception}');
      final raw = result.data?['getKgqlModelType'];
      expect(raw, isNotNull);
      final list = raw is String ? json.decode(raw) as List<dynamic> : raw as List<dynamic>;
      expect(list, isNotEmpty);
      final first = list.first as Map<String, dynamic>;
      ModelType.fromJson(first, recursive: true);
    });

    test('IN13.2 live getKgqlModels no parse exception', () async {
      final result = await client.query(
        QueryOptions(
          document: gql(kgqlGetKgqlModelsQuery),
          variables: {
            'filter': {'model_type': 'Expense'},
            'struct': {'id': true, 'name': true},
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (result.hasException) {
        fail('GraphQL error: ${result.exception}');
      }
      final raw = result.data?['getKgqlModels'];
      expect(raw, isNotNull);
      if (raw is String) {
        json.decode(raw);
      }
    });

    test('IN13.3 live aggregate parseable', () async {
      final out = await getKgqlAggregate(
        client,
        {'model_type': 'Expense'},
        {'metric': 'count', 'key': null, 'group': null},
      );
      expect(out, isNotEmpty);
    });
  }, skip: !_runIntegration);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexus_voice_assistant/data/logs/kgql_log_repository.dart';
import 'package:nexus_voice_assistant/domain/logs/log_records.dart';
import 'package:nexus_voice_assistant/features/logs/logs_providers.dart';
import '../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('log screen receives app records through the repository boundary',
      () async {
    final client = MockGraphQLClient();
    when(() => client.query(any())).thenAnswer((_) async => okQueryResult({
          'logsForDay': [
            {
              'id': '7',
              'time': '2026-10-03T12:00:00.123456Z',
              'event_name': 'agent_run_start',
              'trace_id': 'run-1',
              'payload': {
                'nested': {'value': 42}
              }
            }
          ],
        }));
    final container = ProviderContainer(overrides: [
      logRepositoryProvider.overrideWithValue(KgqlLogRepository(client)),
    ]);
    addTearDown(container.dispose);
    final date = DateTime(2026, 10, 3, 15);
    final rows = await container.read(logsForDayProvider(date).future);
    expect(rows.single, isA<NexusLogRow>());
    expect(rows.single.id, '7');
    expect(rows.single.eventName, 'agent_run_start');
    expect(rows.single.traceId, 'run-1');
    expect(rows.single.time!.microsecond, 456);
    expect(rows.single.payload, {
      'nested': {'value': 42}
    });
    final query = verify(() => client.query(captureAny())).captured.single
        as QueryOptions;
    expect(query.variables['start'],
        DateTime(2026, 10, 3).toUtc().toIso8601String());
  });

  test('correction updates use exact stored timestamp and preserve payload',
      () async {
    final client = MockGraphQLClient();
    const timestamp = '2026-10-03T12:00:00.123456Z';
    when(() => client.query(any())).thenAnswer((_) async => okQueryResult({
          'allLogs': {
            'nodes': [
              {'id': '7', 'time': timestamp}
            ]
          },
        }));
    when(() => client.mutate(any())).thenAnswer((_) async => okQueryResult({}));
    final payload = {
      'original': true,
      'correction': {'note': 'fixed'}
    };
    await KgqlLogRepository(client).updatePayload('7', payload);
    final mutation = verify(() => client.mutate(captureAny())).captured.single
        as MutationOptions;
    expect(
        mutation.variables, {'id': '7', 'time': timestamp, 'payload': payload});
  });

  for (final nodes in [
    <Map<String, dynamic>>[],
    [
      {'id': '7'}
    ]
  ]) {
    test('missing row or exact time prevents correction writes: $nodes',
        () async {
      final client = MockGraphQLClient();
      when(() => client.query(any())).thenAnswer((_) async => okQueryResult({
            'allLogs': {'nodes': nodes},
          }));
      await expectLater(
          KgqlLogRepository(client).updatePayload('7', {}), throwsStateError);
      verifyNever(() => client.mutate(any()));
    });
  }

  test('operation and event lookups map identifiers and before/after values',
      () async {
    final client = MockGraphQLClient();
    final repository = KgqlLogRepository(client);
    when(() => client.query(any())).thenAnswer((_) async => okQueryResult({
          'allChangeOperations': {
            'nodes': [
              {
                'id': 'op',
                'sourceKind': 'agent',
                'domainId': '3',
                'reversedByOperationId': 'undo'
              }
            ]
          },
        }));
    final operation = await repository.operation('op');
    expect(operation, isA<DbChangeOperation>());
    expect(operation!.domainId, '3');
    expect(operation.reversedByOperationId, 'undo');
    when(() => client.query(any())).thenAnswer((_) async => okQueryResult({
          'allChangeEvents': {
            'nodes': [
              {
                'id': 'event',
                'operationId': 'op',
                'tableName': 'models',
                'op': 'update',
                'rowPk': {'id': 9},
                'beforeRow': {'name': 'before'},
                'afterRow': {'name': 'after'}
              }
            ]
          },
        }));
    final event = (await repository.events('op')).single;
    expect(event, isA<DbChangeEvent>());
    expect(event.operationId, 'op');
    expect(event.rowPk, {'id': 9});
    expect(event.beforeRow, {'name': 'before'});
    expect(event.afterRow, {'name': 'after'});
  });

  test('metadata supports model and attribute labels with missing-ID fallbacks',
      () async {
    final client = MockGraphQLClient();
    when(() => client.query(any())).thenAnswer((_) async => okQueryResult({
          'allModelTypes': {
            'nodes': [
              {'id': 1, 'name': 'Person'}
            ]
          },
          'allAttributeDefinitions': {
            'nodes': [
              {'id': 2, 'key': 'image_url'}
            ]
          },
          'allRelationshipTypes': {
            'nodes': [
              {'id': 3, 'relationName': 'with_person'}
            ]
          },
          'allRelationAttributeDefinitions': {
            'nodes': [
              {'id': 4, 'key': 'role'}
            ]
          },
        }));
    final metadata = await KgqlLogRepository(client).metadata();
    expect(metadata.modelTypeName('1'), 'Person');
    expect(metadata.attributeKey(2), 'image_url');
    expect(metadata.modelTypeName(null), 'model_type -');
    expect(metadata.attributeKey(999), 'attribute 999');
    expect(metadata.relationshipTypes[3]!['relationName'], 'with_person');
    expect(metadata.relationAttributeDefinitions[4]!['key'], 'role');
  });
}

import 'dart:io';
import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:nx_time/data/sync/time_store.dart';
import 'package:nx_time/data/sync/time_session.dart';

void main() {
  test('a local request can finish after the default GraphQL timeout', () async {
    final directory = await Directory(
      '${Platform.environment['NEXUS_TEST_TMP'] ?? Directory.systemTemp.path}/slow-time-session',
    ).create(recursive: true);
    final store = TimeStore(
      FileLibrary(
        database: LibraryDatabase(NativeDatabase.memory()),
        files: DirectoryContentFiles(directory),
      ),
      const AccountIdentity(
        serverId: 'test',
        userId: '1',
        domainId: 1,
        application: 'time',
      ),
    );
    final remote = GraphQLClient(
      cache: GraphQLCache(),
      link: Link.function((request, [forward]) async* {
        await Future<void>.delayed(const Duration(seconds: 6));
        yield const Response(
          response: {},
          data: {'__typename': 'Query', 'slowView': 'ready'},
        );
      }),
    );
    final session = TimeSession(
      User(userId: '1', preset: BackendPreset.localhost, domainId: 1),
      1,
      remote,
      storage: store,
    );
    addTearDown(session.close);
    final result = await session.client.query(
      QueryOptions(
        document: gql('query { slowView }'),
        fetchPolicy: FetchPolicy.noCache,
      ),
    );
    expect(result.hasException, isFalse);
    expect(result.data?['slowView'], 'ready');
  });

  test(
    'schedules use the scoped server view even when absent from the manifest',
    () async {
      final directory = await Directory(
        '${Platform.environment['NEXUS_TEST_TMP'] ?? Directory.systemTemp.path}/schedule-session',
      ).create(recursive: true);
      final store = TimeStore(
        FileLibrary(
          database: LibraryDatabase(NativeDatabase.memory()),
          files: DirectoryContentFiles(directory),
        ),
        const AccountIdentity(
          serverId: 'test',
          userId: '1',
          domainId: 1,
          application: 'time',
        ),
      );
      var calls = 0;
      final remote = GraphQLClient(
        cache: GraphQLCache(),
        link: Link.function((request, [forward]) async* {
          calls++;
          expect(request.variables['domainId'], 1);
          yield Response(
            response: const {},
            data: {
              '__typename': 'Query',
              'getKgqlModels': [
                {
                  'id': 9389,
                  'name': 'Pilates',
                  'entries': [
                    {
                      'days': ['thursday'],
                      'start_time': '06:00',
                      'end_time': '07:00',
                    },
                  ],
                },
              ],
            },
          );
        }),
      );
      final session = TimeSession(
        User(userId: '1', preset: BackendPreset.localhost, domainId: 1),
        1,
        remote,
        storage: store,
      );
      await session.outbox.close();
      for (var i = 0; i < 2; i++) {
        final rows = await fetchKgqlModels(
          session.client,
          domainId: 1,
          filter: {'model_type': 'Schedule'},
          struct: {'id': true, 'name': true, 'entries': true},
        );
        expect(rows.single.name, 'Pilates');
      }
      expect(calls, 1);
      await session.close();
    },
  );

  test(
    'nested Routine goal write stays atomic and refreshes cached schedules',
    () async {
      final directory = await Directory(
        '${Directory.systemTemp.path}/routine-atomic-session',
      ).create(recursive: true);
      final store = TimeStore(
        FileLibrary(
          database: LibraryDatabase(NativeDatabase.memory()),
          files: DirectoryContentFiles(directory),
        ),
        const AccountIdentity(
          serverId: 'test',
          userId: '1',
          domainId: 1,
          application: 'time',
        ),
      );
      var updated = false;
      var writes = 0;
      final remote = GraphQLClient(
        cache: GraphQLCache(),
        link: Link.function((request, [forward]) async* {
          if (request.isMutation) {
            writes++;
            final data = (request.variables['input'] as Map)['data'];
            expect(data['relations'][0]['relation_name'], 'routine_goal');
            expect(data['relations'][0]['create'][0]['id'], 90);
            updated = true;
            yield const Response(
              response: {},
              data: {
                '__typename': 'Mutation',
                'setKgqlModels': {
                  '__typename': 'SetKgqlModelsPayload',
                  'json': {'id': 1},
                },
              },
            );
          } else {
            yield Response(
              response: {},
              data: {
                '__typename': 'Query',
                'getKgqlModels': [
                  {
                    'id': 91,
                    'name': updated ? 'Updated schedule' : 'Old schedule',
                  },
                ],
              },
            );
          }
        }),
      );
      final session = TimeSession(
        User(userId: '1', preset: BackendPreset.localhost, domainId: 1),
        1,
        remote,
        storage: store,
      );
      addTearDown(session.close);
      Future<List<Model>> plans() => fetchKgqlModels(
        session.client,
        domainId: 1,
        filter: {'model_type': 'Schedule'},
        struct: {'id': true, 'name': true},
      );
      expect((await plans()).single.name, 'Old schedule');
      final id = await setKgqlModel(
        session.client,
        SetModelRequest(
          id: 1,
          modelType: 'Goal',
          relations: [
            ModelRelation(
              modelType: 'Routine',
              relationName: 'routine_goal',
              create: [
                {
                  'id': 90,
                  'attributes': [
                    {'key': 'start_date', 'value': '2026-10-01'},
                  ],
                },
              ],
            ),
          ],
        ),
        domainId: 1,
      );
      expect(id, 1);
      expect(writes, 1);
      expect((await plans()).single.name, 'Updated schedule');
      expect(await store.pendingMutations(), isEmpty);
    },
  );

  test(
    'cached tasks read without network and edits queue through existing KGQL API',
    () async {
      final directory = await Directory(
        '${Platform.environment['NEXUS_TEST_TMP'] ?? Directory.systemTemp.path}/time-session',
      ).create(recursive: true);
      final library = FileLibrary(
        database: LibraryDatabase(NativeDatabase.memory()),
        files: DirectoryContentFiles(directory),
      );
      final store = TimeStore(
        library,
        const AccountIdentity(
          serverId: 'test',
          userId: '1',
          domainId: 1,
          application: 'time',
        ),
      );
      await store.applySnapshot(
        [
          {
            'id': 0,
            'hash': 'schema',
            'payload': {
              'id': 0,
              'kind': 'metadata',
              'schemas': [
                {'id': 1, 'name': 'Task', 'attributes': [], 'relations': []},
              ],
            },
          },
          {
            'id': 1,
            'hash': 'task',
            'payload': {
              'id': 1,
              'name': 'Laundry',
              'kind': 'Task',
              'families': ['Task'],
              'model_type_id': 1,
              'model_type': {'id': 1, 'name': 'Task'},
              'revision': 'r1',
              'status': 'todo',
            },
          },
        ],
        {0, 1},
      );
      final remote = GraphQLClient(
        cache: GraphQLCache(store: InMemoryStore()),
        link: Link.function((request, [forward]) async* {
          throw StateError('No network expected');
        }),
      );
      final session = TimeSession(
        User(userId: '1', preset: BackendPreset.localhost, domainId: 1),
        1,
        remote,
        storage: store,
      );
      await session.outbox.close(); // Keep this test entirely offline.
      final models = await fetchKgqlModels(
        session.client,
        filter: {'model_type': 'Task'},
        struct: {'id': true, 'name': true},
        domainId: 1,
      );
      expect(models.single.name, 'Laundry');
      final id = await setKgqlModel(
        session.client,
        SetModelRequest(id: 1, name: 'Laundry today'),
        domainId: 1,
      );
      expect(id, 1);
      expect((await store.get('1'))!['name'], 'Laundry today');
      expect(await store.pendingMutations(), hasLength(1));
      final frozen = await store.freeze(
        (await store.pendingMutations()).single,
      );
      expect(frozen['client_updated_at'], isNotNull);
      await session.close();
    },
  );
}

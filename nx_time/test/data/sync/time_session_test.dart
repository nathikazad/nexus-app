import 'dart:io';
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

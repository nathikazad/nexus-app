import 'package:nx_people/data/sync/people_synchronizer.dart';
import 'dart:io';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_people/data/sync/people_store.dart';

const account = AccountIdentity(
  serverId: 'test',
  userId: '1',
  domainId: 1,
  application: 'people',
);
Map<String, dynamic> entity(int id, String name, String revision) => {
  'id': id,
  'name': name,
  'kind': 'Person',
  'model_type': {'name': 'Person'},
  'revision': revision,
};

void main() {
  late Directory directory;
  late FileLibrary library;
  late PeopleStore store;
  void open() {
    library = FileLibrary(
      database: LibraryDatabase(
        NativeDatabase(File('${directory.path}/store.sqlite')),
      ),
      files: DirectoryContentFiles(Directory('${directory.path}/files')),
    );
    store = PeopleStore(library, account);
  }

  setUp(() async {
    directory = await (Directory(
      '${Platform.environment["NEXUS_TEST_TMP"] ?? Directory.systemTemp.path}/nx-people-sync',
    )..createSync(recursive: true)).createTemp('people-store-');
    open();
  });
  tearDown(() async {
    await library.close();
    await directory.delete(recursive: true);
  });
  Future<void> seed() => store.applySnapshot(
    [
      {'id': 1, 'hash': 'h1', 'payload': entity(1, 'Original', 'r1')},
    ],
    {1},
  );
  Future<void> edit(
    String op,
    String name, {
    String local = '1',
    bool create = false,
  }) => store.enqueue(
    operationId: op,
    localId: local,
    command: {
      if (!create) 'id': 1,
      if (create) 'model_type': 'Person',
      'name': name,
    },
    optimistic: entity(1, name, 'r1'),
    now: DateTime.now().toUtc(),
  );
  MutationReceipt receipt(String op, int id, String name, String revision) =>
      MutationReceipt(
        operationId: op,
        entityKey: EntityKey(localId: '1', remoteId: id),
        revision: Revision(revision),
        metadata: {
          'result': {
            'status': 'applied',
            'id': id,
            'entity': entity(id, name, revision),
          },
        },
      );

  test('create and frozen request survive process restart', () async {
    await edit(
      'create-operation-01',
      'Groceries',
      local: 'local-1',
      create: true,
    );
    final mutation = (await store.pendingMutations()).single;
    final request = await store.freeze(mutation);
    expect(request['data']['id'], isNull);
    await library.close();
    open();
    expect((await store.get('local-1'))!['name'], 'Groceries');
    expect(
      await store.freeze((await store.pendingMutations()).single),
      request,
    );
    await store.complete(
      receipt(mutation.operationId, 75, 'Groceries', 'created'),
    );
    expect(await store.pendingMutations(), isEmpty);
    expect((await store.get('local-1'))!['id'], 75);
  });

  test(
    'remote pull cannot advance the edit precondition or erase optimistic data',
    () async {
      await seed();
      await edit('edit-operation-01', 'Local');
      await store.applySnapshot(
        [
          {'id': 1, 'hash': 'h2', 'payload': entity(1, 'Other device', 'r2')},
        ],
        {1},
      );
      expect((await store.get('1'))!['name'], 'Local');
      expect(
        (await store.freeze(
          (await store.pendingMutations()).single,
        ))['expected_revision'],
        'r1',
      );
    },
  );

  test(
    'acknowledging an earlier edit preserves a newer edit and chains revisions',
    () async {
      await seed();
      await edit('edit-operation-01', 'First');
      final first = (await store.pendingMutations()).single;
      await store.freeze(first);
      await edit('edit-operation-02', 'Second');
      await store.complete(receipt(first.operationId, 1, 'First', 'r2'));
      expect((await store.get('1'))!['name'], 'Second');
      await store.applySnapshot(
        [
          {'id': 1, 'hash': 'h3', 'payload': entity(1, 'Other device', 'r3')},
        ],
        {1},
      );
      final second = (await store.pendingMutations()).single;
      expect((await store.freeze(second))['expected_revision'], 'r2');
    },
  );

  test(
    'blocked edit holds later edits of same entity but not another people',
    () async {
      await seed();
      await edit('edit-operation-01', 'First');
      await edit('edit-operation-02', 'Second');
      await edit(
        'create-operation-02',
        'Independent',
        local: 'local-2',
        create: true,
      );
      await store.fail(
        'edit-operation-01',
        failure: const SyncFailure(
          kind: SyncFailureKind.conflict,
          message: 'Conflict',
        ),
        retryAt: DateTime.now(),
      );
      final next = await store.claimNext(
        workerId: 'test',
        now: DateTime.now(),
        lease: const Duration(minutes: 1),
      );
      expect(next!.operationId, 'create-operation-02');
    },
  );

  test(
    'deletion membership removes confirmed rows but retains pending edits',
    () async {
      await seed();
      await edit('edit-operation-01', 'Pending');
      await store.applySnapshot([], {});
      expect((await store.get('1'))!['name'], 'Pending');
      expect(await store.pendingMutations(), hasLength(1));
    },
  );
  test(
    'hash changes download changed records only and deletions converge',
    () async {
      var revision = 1;
      var downloads = 0;
      var changes = 0;
      final session = AppSyncSession(
        app: 'people',
        request: (operation, variables) async {
          if (operation == 'state') {
            return {
              'status': 'ready',
              'projection_version': 3,
              'revision': revision,
              'root_hash': 'root$revision',
              'collections': {
                '': {
                  'hash': 'people$revision',
                  'count': revision < 3 ? 1 : 0,
                  'child_count': 0,
                  'parent': null,
                },
              },
            };
          }
          if (variables.containsKey('itemIds')) {
            downloads++;
            return {
              'status': 'ready',
              'revision': revision,
              'projection_version': 3,
              'items': [
                {
                  'id': 'model:1',
                  'hash': 'h$revision',
                  'payload': entity(1, 'Version $revision', 'r$revision'),
                },
              ],
            };
          }
          return {
            'status': 'ready',
            'revision': revision,
            'projection_version': 3,
            'collections': {},
            'manifest': [
              if (revision < 3)
                {
                  'id': 'model:1',
                  'hash': 'h$revision',
                  'collections': [''],
                },
            ],
          };
        },
      );
      final events = <Map<String, Object?>>[];
      final sync = PeopleReconciler(
        store,
        session,
        onChanged: () => changes++,
        telemetry: (event, fields) => events.add({'event': event, ...fields}),
      );
      await sync.pullAll();
      await sync.pullAll();
      expect(events.take(4).map((e) => e['event']).toList(), [
        'pull_started',
        'download_started',
        'download_finished',
        'cache_applied',
      ]);
      expect(events.take(4).map((e) => e['run_id']).toSet(), hasLength(1));
      expect(events[3]['revision'], 1);
      expect(events[2]['record_count'], 1);
      expect(events.toString(), isNot(contains('Version 1')));
      expect(downloads, 1);
      expect(changes, 1);
      revision = 2;
      await sync.pullAll();
      expect(downloads, 2);
      expect((await store.get('1'))!['name'], 'Version 2');
      revision = 3;
      await sync.pullAll();
      expect(await store.get('1'), isNull);
      expect(downloads, 2);
      expect(changes, 3);
    },
  );

  test(
    'incomplete download cannot remove data or acknowledge new coverage',
    () async {
      await seed();
      final session = AppSyncSession(
        request: (operation, variables) async {
          if (operation == 'state') {
            return {
              'status': 'ready',
              'projection_version': 3,
              'revision': 2,
              'root_hash': 'new',
              'collections': {
                '': {
                  'hash': 'new',
                  'count': 1,
                  'child_count': 0,
                  'parent': null,
                },
              },
            };
          }
          return {
            'status': 'ready',
            'revision': 2,
            'projection_version': 3,
            'collections': {},
            'manifest': [
              {
                'id': 2,
                'hash': 'h2',
                'collections': [''],
              },
            ],
            'items': [],
          };
        },
      );
      await expectLater(
        PeopleReconciler(store, session).pullAll(),
        throwsStateError,
      );
      expect((await store.get('1'))!['name'], 'Original');
      expect(await library.read('people_state', 'coverage'), isNull);
    },
  );
  test(
    'server discovery before a lost create receipt does not duplicate the record',
    () async {
      await edit(
        'create-lost-receipt',
        'Alice',
        local: '9000000000000',
        create: true,
      );
      await store.applySnapshot(
        [
          {'id': 75, 'hash': 'h75', 'payload': entity(75, 'Alice', 'r75')},
        ],
        {75},
      );
      await store.complete(receipt('create-lost-receipt', 75, 'Alice', 'r75'));
      expect((await store.all()).where((row) => row['id'] == 75), hasLength(1));
      expect(await store.localId('75'), '9000000000000');
      expect(await store.pendingMutations(), isEmpty);
    },
  );
}

import 'dart:io';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_expense/data/sync/expense_store.dart';

const account = AccountIdentity(
  serverId: 'test',
  userId: '1',
  domainId: 1,
  application: 'expense',
);
Map<String, dynamic> entity(int id, String name, String revision) => {
  'id': id,
  'name': name,
  'kind': 'model',
  'model_type': {'name': 'Expense'},
  'revision': revision,
};

void main() {
  late Directory directory;
  late FileLibrary library;
  late ExpenseStore store;
  void open() {
    library = FileLibrary(
      database: LibraryDatabase(
        NativeDatabase(File('${directory.path}/store.sqlite')),
      ),
      files: DirectoryContentFiles(Directory('${directory.path}/files')),
    );
    store = ExpenseStore(library, account);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('expense-store-');
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
      if (create) 'model_type': 'Expense',
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
    'blocked edit holds later edits of same entity but not another expense',
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
}

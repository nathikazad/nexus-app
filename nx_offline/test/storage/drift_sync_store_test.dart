import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  const account = AccountScope(
    backend: 'production',
    userId: 'user-1',
    application: 'test',
  );
  final now = DateTime.utc(2026, 7, 26);

  LocalEntity entity({
    String value = 'local',
    EntitySyncState state = EntitySyncState.queued,
  }) {
    return LocalEntity(
      account: account,
      collection: 'items',
      key: const EntityKey(localId: 'item-1', remoteId: 1),
      payload: {'value': value},
      updatedAt: now,
      syncState: state,
      revision: const Revision('r1'),
      baseRevision: const Revision('r1'),
    );
  }

  PendingMutation mutation({
    String operationId = 'op-1',
    String value = 'local',
  }) {
    return PendingMutation(
      operationId: operationId,
      account: account,
      collection: 'items',
      entityKey: const EntityKey(localId: 'item-1', remoteId: 1),
      type: MutationType.update,
      payload: {'value': value},
      baseRevision: const Revision('r1'),
      createdAt: now,
    );
  }

  test('entity and outbox mutation commit atomically', () async {
    final database = SyncDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftSyncStore(database: database, account: account);

    await store.saveEntityAndEnqueue(entity(), mutation());

    expect((await store.getEntity('items', entity().key))?.payload, {
      'value': 'local',
    });
    expect(await store.pendingMutations(), hasLength(1));

    await expectLater(
      store.saveEntityAndEnqueue(
        entity(),
        PendingMutation(
          operationId: 'wrong-account',
          account: const AccountScope(
            backend: 'production',
            userId: 'other-user',
            application: 'test',
          ),
          collection: 'items',
          entityKey: entity().key,
          type: MutationType.update,
          payload: const {'value': 'bad'},
          createdAt: now,
        ),
      ),
      throwsStateError,
    );
    expect(await store.pendingMutations(), hasLength(1));
  });

  test('repeated saves coalesce into one durable operation', () async {
    final database = SyncDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftSyncStore(database: database, account: account);

    await store.saveEntityAndEnqueue(entity(), mutation());
    await store.saveEntityAndEnqueue(
      entity(value: 'newest'),
      mutation(operationId: 'op-2', value: 'newest'),
    );

    final pending = await store.pendingMutations();
    expect(pending, hasLength(1));
    expect(pending.single.operationId, 'op-1');
    expect(pending.single.payload, {'value': 'newest'});
    expect((await store.getEntity('items', entity().key))?.payload, {
      'value': 'newest',
    });
  });

  test('claim, failure, and completion update durable entity state', () async {
    final database = SyncDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftSyncStore(database: database, account: account);
    await store.saveEntityAndEnqueue(entity(), mutation());

    final claimed = await store.claimNext(
      workerId: 'worker-1',
      now: now,
      lease: const Duration(minutes: 1),
    );
    expect(claimed?.status, PendingMutationStatus.claimed);
    expect(
      (await store.getEntity('items', entity().key))?.syncState,
      EntitySyncState.syncing,
    );

    await store.fail(
      'op-1',
      failure: const SyncFailure(
        kind: SyncFailureKind.transient,
        message: 'offline',
      ),
      retryAt: now.add(const Duration(seconds: 2)),
    );
    expect(
      (await store.getEntity('items', entity().key))?.syncState,
      EntitySyncState.retryWaiting,
    );

    final reclaimed = await store.claimNext(
      workerId: 'worker-2',
      now: now.add(const Duration(seconds: 2)),
      lease: const Duration(minutes: 1),
    );
    expect(reclaimed?.operationId, 'op-1');

    await store.complete(
      const MutationReceipt(
        operationId: 'op-1',
        entityKey: EntityKey(localId: 'item-1', remoteId: 1),
        revision: Revision('r2'),
      ),
    );
    expect(await store.pendingMutations(), isEmpty);
    final saved = await store.getEntity('items', entity().key);
    expect(saved?.syncState, EntitySyncState.synced);
    expect(saved?.revision, const Revision('r2'));
  });

  test(
    'remote import does not overwrite an entity with pending work',
    () async {
      final database = SyncDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = DriftSyncStore(database: database, account: account);
      await store.saveEntityAndEnqueue(entity(), mutation());

      final imported = await store.importRemote(
        const RemoteRecord(
          collection: 'items',
          modelType: 'Item',
          entityKey: EntityKey(localId: 'item-1', remoteId: 1),
          revision: Revision('r2'),
          payload: {'value': 'remote'},
        ),
        now,
      );

      expect(imported, isFalse);
      expect((await store.getEntity('items', entity().key))?.payload, {
        'value': 'local',
      });
    },
  );

  test('pending work and cursor survive database restart', () async {
    final directory = await Directory.systemTemp.createTemp('nx_offline_test_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sync.sqlite');

    var database = SyncDatabase(NativeDatabase(file));
    var store = DriftSyncStore(database: database, account: account);
    await store.saveEntityAndEnqueue(entity(), mutation());
    await store.writeCursor('items', const SyncCursor('cursor-1'));
    await database.close();

    database = SyncDatabase(NativeDatabase(file));
    addTearDown(database.close);
    store = DriftSyncStore(database: database, account: account);

    expect(await store.pendingMutations(), hasLength(1));
    expect(await store.readCursor('items'), const SyncCursor('cursor-1'));
    expect((await store.getEntity('items', entity().key))?.payload, {
      'value': 'local',
    });
  });

  test('account partitions do not leak in a shared database', () async {
    final database = SyncDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final first = DriftSyncStore(database: database, account: account);
    const otherAccount = AccountScope(
      backend: 'production',
      userId: 'user-2',
      application: 'test',
    );
    final second = DriftSyncStore(database: database, account: otherAccount);

    await first.saveEntityAndEnqueue(entity(), mutation());

    expect(await second.pendingMutations(), isEmpty);
    expect(await second.getEntity('items', entity().key), isNull);
  });
}

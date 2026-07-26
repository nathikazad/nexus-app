import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

import '../support/fakes.dart';

void main() {
  const account = AccountScope(
    backend: 'production',
    userId: 'user-1',
    application: 'test',
  );
  late FakeClock clock;
  late MemorySyncStore store;
  late FakeTransport transport;
  late FakeCollection collection;
  late SyncCoordinator coordinator;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 7, 26));
    store = MemorySyncStore(account);
    transport = FakeTransport();
    collection = FakeCollection('items', {'Item'});
    coordinator = SyncCoordinator(
      store: store,
      transport: transport,
      collections: [collection],
      pushConflictResolvers: [collection],
      clock: clock,
      idGenerator: SequenceIds(),
    );
  });

  tearDown(() => coordinator.dispose());

  PendingMutation mutation(String id) => PendingMutation(
    operationId: id,
    account: account,
    collection: 'items',
    entityKey: EntityKey(localId: id),
    type: MutationType.create,
    payload: {'id': id},
    createdAt: clock.now(),
  );

  test('pushes pending work before pulling remote changes', () async {
    await store.enqueue(mutation('op-1'));
    transport.pages['items'] = RemoteChangePage(
      records: [
        const RemoteRecord(
          collection: 'items',
          modelType: 'Item',
          entityKey: EntityKey(localId: 'remote-9', remoteId: 9),
          revision: Revision('r9'),
          payload: {'name': 'Remote'},
        ),
      ],
      tombstones: const [],
      nextCursor: const SyncCursor('cursor-1'),
    );

    final result = await coordinator.synchronize();

    expect(result.pushedCount, 1);
    expect(result.pulledCount, 1);
    expect(transport.pushed.single.operationId, 'op-1');
    expect(collection.records.single.entityKey.remoteId, 9);
    expect(store.cursors['items'], const SyncCursor('cursor-1'));
    expect(coordinator.status.activity, SyncActivity.idle);
  });

  test('transient failure remains durable and schedules retry', () async {
    await store.enqueue(mutation('op-1'));
    transport.pushFailure = const SyncFailure(
      kind: SyncFailureKind.transient,
      message: 'offline',
    );

    final result = await coordinator.synchronize();
    final pending = await store.pendingMutations();

    expect(result.failureCount, 1);
    expect(pending.single.status, PendingMutationStatus.retryWaiting);
    expect(pending.single.attemptCount, 1);
    expect(pending.single.nextAttemptAt, isNotNull);
    expect(coordinator.status.activity, SyncActivity.retryWaiting);
  });

  test('authentication failure blocks pull', () async {
    await store.enqueue(mutation('op-1'));
    transport.pushFailure = const SyncFailure(
      kind: SyncFailureKind.authentication,
      message: 'sign in',
    );

    final result = await coordinator.synchronize();

    expect(result.failureCount, 1);
    expect(store.cursors, isEmpty);
    expect(coordinator.status.activity, SyncActivity.blocked);
  });

  test('push conflict is handed to its collection before failure', () async {
    await store.enqueue(mutation('op-1'));
    transport.pushFailure = const SyncFailure(
      kind: SyncFailureKind.conflict,
      message: 'stale revision',
    );

    final result = await coordinator.synchronize();

    expect(result.failureCount, 1);
    expect(result.conflictCount, 1);
    expect(collection.pushConflictMutation?.operationId, 'op-1');
    expect(collection.pushConflictFailure?.kind, SyncFailureKind.conflict);
    final pending = (await store.pendingMutations()).single;
    expect(pending.status, PendingMutationStatus.retryWaiting);
    expect(pending.lastError, 'stale revision');
  });

  test('push conflict resolver can be registered independently', () async {
    final resolver = _StandaloneConflictResolver();
    final separateCoordinator = SyncCoordinator(
      store: store,
      transport: transport,
      collections: [
        FakeCollection('items', {'Item'}),
      ],
      pushConflictResolvers: [resolver],
      clock: clock,
      idGenerator: SequenceIds(),
    );
    addTearDown(separateCoordinator.dispose);
    await store.enqueue(mutation('op-1'));
    transport.pushFailure = const SyncFailure(
      kind: SyncFailureKind.conflict,
      message: 'stale revision',
    );

    await separateCoordinator.synchronize();

    expect(resolver.seen?.operationId, 'op-1');
  });

  test('concurrent triggers share one synchronization run', () async {
    await store.enqueue(mutation('op-1'));
    transport.pushGate = Completer<void>();

    final first = coordinator.synchronize();
    final second = coordinator.synchronize();
    expect(identical(first, second), isTrue);

    transport.pushGate!.complete();
    await first;
    expect(transport.pushed, hasLength(1));
  });

  test('conflict is durably recorded and handed to adapter', () async {
    const remote = RemoteRecord(
      collection: 'items',
      modelType: 'Item',
      entityKey: EntityKey(localId: 'remote-1', remoteId: 1),
      revision: Revision('remote-r2'),
      payload: {'value': 'remote'},
    );
    collection.conflict = SyncConflict(
      account: account,
      collection: 'items',
      entityKey: remote.entityKey,
      localPayload: const {'value': 'local'},
      remotePayload: remote.payload,
      remoteRevision: remote.revision,
      detectedAt: clock.now(),
    );
    transport.pages['items'] = const RemoteChangePage(
      records: [remote],
      tombstones: [],
      nextCursor: SyncCursor('cursor-2'),
    );

    final result = await coordinator.synchronize();

    expect(store.conflicts, hasLength(1));
    expect(collection.preserved, [remote]);
    expect(result.conflictCount, 1);
    expect(result.succeeded, isFalse);
  });
}

final class _StandaloneConflictResolver implements PushConflictResolver {
  @override
  String get collectionName => 'items';

  PendingMutation? seen;

  @override
  Future<void> resolvePushConflict({
    required PendingMutation mutation,
    required SyncFailure failure,
  }) async {
    seen = mutation;
  }
}

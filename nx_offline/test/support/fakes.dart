import 'dart:async';

import 'package:nx_offline/nx_offline.dart';

final class FakeClock implements Clock {
  FakeClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class SequenceIds implements IdGenerator {
  int _value = 0;

  @override
  String nextId() => '${_value++}';
}

final class MemorySyncStore implements SyncStore {
  MemorySyncStore(this.account);

  @override
  final AccountScope account;

  final List<PendingMutation> mutations = [];
  final Map<String, SyncCursor> cursors = {};
  final List<SyncConflict> conflicts = [];

  @override
  Future<void> enqueue(PendingMutation mutation) async {
    if (mutation.account != account) throw StateError('account mismatch');
    mutations.add(mutation);
  }

  @override
  Future<List<PendingMutation>> pendingMutations() async =>
      List.unmodifiable(mutations);

  @override
  Future<PendingMutation?> claimNext({
    required String workerId,
    required DateTime now,
    required Duration lease,
  }) async {
    for (var index = 0; index < mutations.length; index++) {
      final mutation = mutations[index];
      if (!mutation.isEligibleAt(now)) continue;
      final claimed = mutation.copyWith(
        status: PendingMutationStatus.claimed,
        leaseOwner: workerId,
        leaseExpiresAt: now.add(lease),
        clearNextAttemptAt: true,
      );
      mutations[index] = claimed;
      return claimed;
    }
    return null;
  }

  @override
  Future<void> complete(MutationReceipt receipt) async {
    mutations.removeWhere(
      (mutation) => mutation.operationId == receipt.operationId,
    );
  }

  @override
  Future<void> fail(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  }) async {
    final index = mutations.indexWhere(
      (mutation) => mutation.operationId == operationId,
    );
    if (index < 0) throw StateError('mutation not found');
    final mutation = mutations[index];
    mutations[index] = mutation.copyWith(
      status: PendingMutationStatus.retryWaiting,
      attemptCount: mutation.attemptCount + 1,
      nextAttemptAt: retryAt,
      lastError: failure.message,
      clearLease: true,
    );
  }

  @override
  Future<SyncCursor?> readCursor(String collection) async =>
      cursors[collection];

  @override
  Future<void> writeCursor(String collection, SyncCursor cursor) async {
    cursors[collection] = cursor;
  }

  @override
  Future<void> recordConflict(SyncConflict conflict) async {
    conflicts.add(conflict);
  }
}

final class FakeTransport implements SyncTransport {
  final List<PendingMutation> pushed = [];
  final Map<String, RemoteChangePage> pages = {};
  int pullCount = 0;
  SyncFailure? pushFailure;
  SyncFailure? pullFailure;
  Completer<void>? pushGate;

  @override
  Future<MutationReceipt> push(PendingMutation mutation) async {
    pushed.add(mutation);
    await pushGate?.future;
    final failure = pushFailure;
    if (failure != null) throw SyncTransportException(failure);
    return MutationReceipt(
      operationId: mutation.operationId,
      entityKey:
          mutation.entityKey.remoteId == null &&
              mutation.type == MutationType.create
          ? mutation.entityKey.withRemoteId(100 + pushed.length)
          : mutation.entityKey,
      revision: const Revision('server-revision'),
    );
  }

  @override
  Future<RemoteChangePage> pull({
    required AccountScope account,
    required String collection,
    required Set<String> modelTypes,
    required SyncCursor? cursor,
  }) async {
    pullCount++;
    final failure = pullFailure;
    if (failure != null) throw SyncTransportException(failure);
    return pages[collection] ??
        const RemoteChangePage(
          records: [],
          tombstones: [],
          nextCursor: SyncCursor('empty'),
        );
  }
}

final class FakeCollection
    implements SyncCollectionAdapter, PushConflictResolver {
  FakeCollection(this.collectionName, this.modelTypes);

  @override
  final String collectionName;

  @override
  final Set<String> modelTypes;

  final List<RemoteRecord> records = [];
  final List<RemoteTombstone> tombstones = [];
  final List<RemoteRecord> preserved = [];
  SyncConflict? conflict;
  PendingMutation? pushConflictMutation;
  SyncFailure? pushConflictFailure;

  @override
  Future<void> applyRemote(RemoteRecord record) async {
    final pendingConflict = conflict;
    if (pendingConflict != null) {
      conflict = null;
      throw CollectionConflictException(pendingConflict);
    }
    records.add(record);
  }

  @override
  Future<void> applyTombstone(RemoteTombstone tombstone) async {
    tombstones.add(tombstone);
  }

  @override
  Future<void> preserveConflict(RemoteRecord remote) async {
    preserved.add(remote);
  }

  @override
  Future<void> resolvePushConflict({
    required PendingMutation mutation,
    required SyncFailure failure,
  }) async {
    pushConflictMutation = mutation;
    pushConflictFailure = failure;
  }
}

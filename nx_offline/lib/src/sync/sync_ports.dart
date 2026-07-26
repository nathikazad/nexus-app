import '../core/sync_models.dart';

abstract interface class SyncStore {
  AccountScope get account;

  Future<void> enqueue(PendingMutation mutation);

  Future<List<PendingMutation>> pendingMutations();

  Future<PendingMutation?> claimNext({
    required String workerId,
    required DateTime now,
    required Duration lease,
  });

  Future<void> complete(MutationReceipt receipt);

  Future<void> fail(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  });

  Future<SyncCursor?> readCursor(String collection);

  Future<void> writeCursor(String collection, SyncCursor cursor);

  Future<void> recordConflict(SyncConflict conflict);
}

abstract interface class SyncTransport {
  Future<MutationReceipt> push(PendingMutation mutation);

  Future<RemoteChangePage> pull({
    required AccountScope account,
    required String collection,
    required Set<String> modelTypes,
    required SyncCursor? cursor,
  });
}

abstract interface class SyncCollectionAdapter {
  String get collectionName;

  Set<String> get modelTypes;

  Future<void> applyRemote(RemoteRecord record);

  Future<void> applyTombstone(RemoteTombstone tombstone);

  Future<void> preserveConflict(RemoteRecord remote);
}

/// Optional collection capability for preserving both sides of a conflict
/// discovered while pushing a conditional mutation.
///
/// A coordinator invokes this before marking the outbox mutation failed. The
/// implementation is responsible for fetching the current remote entity and
/// durably preserving it alongside the local version.
abstract interface class PushConflictResolver {
  String get collectionName;

  Future<void> resolvePushConflict({
    required PendingMutation mutation,
    required SyncFailure failure,
  });
}

final class CollectionConflictException implements Exception {
  const CollectionConflictException(this.conflict);

  final SyncConflict conflict;
}

abstract interface class Clock {
  DateTime now();
}

abstract interface class IdGenerator {
  String nextId();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

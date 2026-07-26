import '../core/sync_models.dart';
import '../sync/sync_ports.dart';

final class KgqlSyncCapabilities {
  const KgqlSyncCapabilities({
    required this.durableIdempotency,
    required this.atomicRevisions,
    required this.incrementalCursor,
    required this.tombstones,
  });

  const KgqlSyncCapabilities.compatibility()
    : durableIdempotency = false,
      atomicRevisions = false,
      incrementalCursor = false,
      tombstones = false;

  final bool durableIdempotency;
  final bool atomicRevisions;
  final bool incrementalCursor;
  final bool tombstones;

  bool get hasProductionGuarantees =>
      durableIdempotency && atomicRevisions && incrementalCursor && tombstones;
}

abstract interface class KgqlMutationExecutor {
  Future<MutationReceipt> execute(PendingMutation mutation);
}

abstract interface class KgqlChangeSource {
  Future<RemoteChangePage> load({
    required AccountScope account,
    required String collection,
    required Set<String> modelTypes,
    required SyncCursor? cursor,
  });
}

/// KGQL-facing transport boundary.
///
/// Applications provide schema-aware mutation and change adapters because
/// KGQL model structures differ by collection. This class normalizes failures
/// and exposes backend capability guarantees to the rest of the application.
final class KgqlSyncTransport implements SyncTransport {
  const KgqlSyncTransport({
    required this.mutations,
    required this.changes,
    this.capabilities = const KgqlSyncCapabilities.compatibility(),
  });

  final KgqlMutationExecutor mutations;
  final KgqlChangeSource changes;
  final KgqlSyncCapabilities capabilities;

  @override
  Future<MutationReceipt> push(PendingMutation mutation) async {
    try {
      return await mutations.execute(mutation);
    } on SyncTransportException {
      rethrow;
    } catch (error) {
      throw SyncTransportException(
        SyncFailure(kind: SyncFailureKind.transient, message: error.toString()),
      );
    }
  }

  @override
  Future<RemoteChangePage> pull({
    required AccountScope account,
    required String collection,
    required Set<String> modelTypes,
    required SyncCursor? cursor,
  }) async {
    try {
      return await changes.load(
        account: account,
        collection: collection,
        modelTypes: modelTypes,
        cursor: cursor,
      );
    } on SyncTransportException {
      rethrow;
    } catch (error) {
      throw SyncTransportException(
        SyncFailure(kind: SyncFailureKind.transient, message: error.toString()),
      );
    }
  }
}

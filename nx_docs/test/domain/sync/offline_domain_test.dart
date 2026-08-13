import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/domain/document/document_identity.dart';
import 'package:nx_docs/domain/sync/document_revision.dart';
import 'package:nx_docs/domain/sync/pending_operation.dart';
import 'package:nx_docs/domain/sync/sync_failure.dart';
import 'package:nx_docs/domain/sync/sync_state.dart';

void main() {
  group('DocumentKey', () {
    test('keeps local identity when a remote id is assigned', () {
      const local = DocumentKey(localId: 'local-1');
      final remote = local.withRemoteId(42);

      expect(remote.localId, 'local-1');
      expect(remote.remoteId, 42);
      expect(remote, local);
    });

    test('rejects non-positive remote ids', () {
      expect(
        () => const DocumentKey(localId: 'a').withRemoteId(0),
        throwsArgumentError,
      );
    });
  });

  test('remote revisions compare by opaque value', () {
    expect(const RemoteRevision('one'), const RemoteRevision('one'));
    expect(const RemoteRevision('one'), isNot(const RemoteRevision('two')));
  });

  group('sync state transitions', () {
    test('allows the normal save and sync lifecycle', () {
      expect(
        DocumentSyncState.synced.canTransitionTo(
          DocumentSyncState.locallyModified,
        ),
        isTrue,
      );
      expect(
        DocumentSyncState.locallyModified.canTransitionTo(
          DocumentSyncState.queued,
        ),
        isTrue,
      );
      expect(
        DocumentSyncState.queued.canTransitionTo(DocumentSyncState.syncing),
        isTrue,
      );
      expect(
        DocumentSyncState.syncing.canTransitionTo(DocumentSyncState.synced),
        isTrue,
      );
    });

    test('rejects skipping directly from synced to syncing', () {
      expect(
        DocumentSyncState.synced.canTransitionTo(DocumentSyncState.syncing),
        isFalse,
      );
    });
  });

  test('claimed operation becomes eligible only after lease expiry', () {
    final now = DateTime.utc(2026, 1, 1, 12);
    final operation = PendingOperation(
      operationId: 'op',
      accountKey: 'account',
      documentKey: const DocumentKey(localId: 'doc'),
      type: PendingOperationType.update,
      payload: const <String, Object?>{},
      status: PendingOperationStatus.claimed,
      leaseOwner: 'worker',
      leaseExpiresAt: now.add(const Duration(minutes: 1)),
      createdAt: now,
    );

    expect(operation.isEligibleAt(now), isFalse);
    expect(operation.isEligibleAt(now.add(const Duration(minutes: 1))), isTrue);
  });

  test('only transient and unknown failures are retryable', () {
    expect(
      const SyncFailure(
        kind: SyncFailureKind.transient,
        message: 'down',
      ).isRetryable,
      isTrue,
    );
    expect(
      const SyncFailure(
        kind: SyncFailureKind.authentication,
        message: 'denied',
      ).isRetryable,
      isFalse,
    );
  });
}

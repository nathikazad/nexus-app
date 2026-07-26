import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test('entity key preserves local identity when assigned a remote id', () {
    const local = EntityKey(localId: 'local-1');
    final remote = local.withRemoteId(42);

    expect(remote.localId, local.localId);
    expect(remote.remoteId, 42);
  });

  test('claimed mutation becomes eligible only after lease expiry', () {
    final now = DateTime.utc(2026, 7, 26);
    final mutation = PendingMutation(
      operationId: 'op-1',
      account: const AccountScope(
        backend: 'production',
        userId: 'user-1',
        application: 'test',
      ),
      collection: 'items',
      entityKey: const EntityKey(localId: 'item-1'),
      type: MutationType.create,
      payload: const {'name': 'Test'},
      createdAt: now,
      status: PendingMutationStatus.claimed,
      leaseOwner: 'worker',
      leaseExpiresAt: now.add(const Duration(minutes: 1)),
    );

    expect(mutation.isEligibleAt(now), isFalse);
    expect(mutation.isEligibleAt(now.add(const Duration(minutes: 1))), isTrue);
  });

  test('only transient and unknown failures retry', () {
    for (final kind in SyncFailureKind.values) {
      final failure = SyncFailure(kind: kind, message: 'failure');
      expect(
        failure.isRetryable,
        kind == SyncFailureKind.transient || kind == SyncFailureKind.unknown,
      );
    }
  });
}

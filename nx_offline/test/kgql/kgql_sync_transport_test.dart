import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  const account = AccountScope(
    backend: 'production',
    userId: 'user-1',
    application: 'test',
  );
  final mutation = PendingMutation(
    operationId: 'op-1',
    account: account,
    collection: 'items',
    entityKey: const EntityKey(localId: 'item-1'),
    type: MutationType.create,
    payload: const {'model_type': 'Item', 'name': 'Test'},
    createdAt: DateTime.utc(2026, 7, 26),
  );

  test('delegates schema-aware push and pull operations', () async {
    final executor = _MutationExecutor();
    final source = _ChangeSource();
    final transport = KgqlSyncTransport(
      mutations: executor,
      changes: source,
      capabilities: const KgqlSyncCapabilities(
        durableIdempotency: true,
        atomicRevisions: true,
        incrementalCursor: true,
        tombstones: true,
      ),
    );

    final receipt = await transport.push(mutation);
    final page = await transport.pull(
      account: account,
      collection: 'items',
      modelTypes: {'Item'},
      cursor: const SyncCursor('cursor-1'),
    );

    expect(receipt.entityKey.remoteId, 9);
    expect(executor.seen?.operationId, 'op-1');
    expect(source.collection, 'items');
    expect(source.modelTypes, {'Item'});
    expect(page.nextCursor, const SyncCursor('cursor-2'));
    expect(transport.capabilities.hasProductionGuarantees, isTrue);
  });

  test('normalizes unexpected adapter failures as transient', () async {
    final transport = KgqlSyncTransport(
      mutations: _MutationExecutor(error: StateError('network')),
      changes: _ChangeSource(),
    );

    await expectLater(
      transport.push(mutation),
      throwsA(
        isA<SyncTransportException>().having(
          (error) => error.failure.kind,
          'kind',
          SyncFailureKind.transient,
        ),
      ),
    );
    expect(transport.capabilities.hasProductionGuarantees, isFalse);
  });

  test('preserves classified transport failures', () async {
    const failure = SyncFailure(
      kind: SyncFailureKind.authentication,
      message: 'unauthorized',
    );
    final transport = KgqlSyncTransport(
      mutations: _MutationExecutor(
        error: const SyncTransportException(failure),
      ),
      changes: _ChangeSource(),
    );

    await expectLater(
      transport.push(mutation),
      throwsA(
        isA<SyncTransportException>().having(
          (error) => error.failure.kind,
          'kind',
          SyncFailureKind.authentication,
        ),
      ),
    );
  });
}

final class _MutationExecutor implements KgqlMutationExecutor {
  _MutationExecutor({this.error});

  final Object? error;
  PendingMutation? seen;

  @override
  Future<MutationReceipt> execute(PendingMutation mutation) async {
    seen = mutation;
    if (error case final Object error) throw error;
    return MutationReceipt(
      operationId: mutation.operationId,
      entityKey: mutation.entityKey.withRemoteId(9),
      revision: const Revision('r1'),
    );
  }
}

final class _ChangeSource implements KgqlChangeSource {
  String? collection;
  Set<String>? modelTypes;

  @override
  Future<RemoteChangePage> load({
    required AccountScope account,
    required String collection,
    required Set<String> modelTypes,
    required SyncCursor? cursor,
  }) async {
    this.collection = collection;
    this.modelTypes = modelTypes;
    return const RemoteChangePage(
      records: [],
      tombstones: [],
      nextCursor: SyncCursor('cursor-2'),
    );
  }
}

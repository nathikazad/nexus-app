import 'dart:convert';
import 'package:nx_offline/nx_offline.dart';
import 'expense_store.dart';
import 'expense_transport.dart';

class ExpenseMutationHandler implements MutationHandler {
  ExpenseMutationHandler(this.store, this.remote);
  final ExpenseStore store;
  final ExpenseTransport remote;
  @override
  String get collection => 'expense';
  @override
  Future<MutationReceipt> execute(PendingMutation mutation) async {
    final request = await store.freeze(mutation);
    final result = await remote.execute(request);
    if (result['status'] == 'conflict') {
      // Keep the server version alongside the untouched local version.
      await store.library.saveRemote(
        'expense_conflicts',
        mutation.operationId,
        jsonEncode(result),
      );
      throw const SyncTransportException(
        SyncFailure(
          kind: SyncFailureKind.conflict,
          message:
              'This expense changed on another device. Review both versions.',
        ),
      );
    }
    return MutationReceipt(
      operationId: mutation.operationId,
      entityKey: EntityKey(
        localId: mutation.payload['local_id']! as String,
        remoteId: result['id'] as int,
      ),
      revision: Revision(result['entity']?['revision'] as String? ?? 'deleted'),
      metadata: {'result': result},
    );
  }
}

class ExpenseReconciler implements PullReconciler<int> {
  ExpenseReconciler(
    this.store,
    this.session, {
    this.onChanged,
    this.syncAssets,
  });
  final void Function()? onChanged;
  final Future<void> Function()? syncAssets;
  final ExpenseStore store;
  final AppSyncSession session;
  @override
  Future<void> pullAll() async {
    final manifest = await session.manifest();
    if (manifest == null) {
      throw StateError('Expense synchronization is unavailable');
    }
    final hashes = await store.hashes();
    final wanted = <int>{
      for (final entry in manifest.entries)
        if (hashes[entry['id']] != entry['hash']) entry['id'] as int,
    };
    final items = await session.download(manifest, wanted);
    await store.applySnapshot(items, {
      for (final entry in manifest.entries) entry['id'] as int,
    });
    await store.library.saveRemote(
      'expense_state',
      'coverage',
      jsonEncode({
        'revision': manifest.revision,
        'root': manifest.root,
        'complete': true,
      }),
    );
    if (wanted.isNotEmpty ||
        hashes.keys.any(
          (id) => !manifest.entries.any((entry) => entry['id'] == id),
        )) {
      onChanged?.call();
    }
    await syncAssets?.call();
  }

  @override
  Future<void> pullKeys(Set<int> keys) => pullAll();
}

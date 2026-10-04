import 'dart:convert';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_time/data/sync/time_store.dart';
import 'package:nx_time/data/sync/time_transport.dart';

class TimeMutationHandler implements MutationHandler {
  TimeMutationHandler(this.store, this.remote);
  final TimeStore store;
  final TimeTransport remote;
  @override
  String get collection => 'time';
  @override
  Future<MutationReceipt> execute(PendingMutation mutation) async {
    final request = await store.freeze(mutation);
    final result = await remote.execute(request);
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

class TimeReconciler implements PullReconciler<int> {
  TimeReconciler(this.store, this.session, {this.onChanged, this.syncAssets});
  final void Function()? onChanged;
  final Future<void> Function()? syncAssets;
  final TimeStore store;
  final AppSyncSession session;
  @override
  Future<void> pullAll() async {
    final manifest = await session.manifest();
    if (manifest == null) {
      throw StateError('Time synchronization is unavailable');
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
      'time_state',
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

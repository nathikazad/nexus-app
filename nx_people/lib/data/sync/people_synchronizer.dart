import 'package:nx_db/app_sync.dart' show syncTrace, SyncTraceSink;
import 'package:nx_people/data/sync/people_assets.dart';
import 'dart:convert';
import 'package:nx_people/data/sync/people_data_repository.dart'
    show peopleOperationId;
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_people/data/sync/people_store.dart';
import 'package:nx_people/data/sync/people_transport.dart';

class PeopleMutationHandler implements MutationHandler {
  PeopleMutationHandler(this.store, this.remote, {this.assets});
  final PeopleAssets? assets;
  final PeopleStore store;
  final PeopleTransport remote;
  @override
  String get collection => 'people';
  @override
  Future<MutationReceipt> execute(PendingMutation mutation) async {
    final prepared = await assets?.resolve(mutation.payload['command']);
    final request = await store.freeze(
      mutation,
      prepared: prepared == null
          ? null
          : Map<String, dynamic>.from(prepared as Map),
    );
    final result = await remote.execute(request);
    if (result['status'] == 'conflict') {
      // Keep the server version alongside the untouched local version.
      await store.library.saveRemote(
        'people_conflicts',
        mutation.operationId,
        jsonEncode(result),
      );
      throw const SyncTransportException(
        SyncFailure(
          kind: SyncFailureKind.conflict,
          message:
              'This record changed on another device. Review both versions.',
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

class PeopleReconciler implements PullReconciler<int> {
  PeopleReconciler(
    this.store,
    this.session, {
    this.onChanged,
    this.syncAssets,
    this.telemetry,
  });
  final SyncTraceSink? telemetry;
  final void Function()? onChanged;
  final Future<void> Function()? syncAssets;
  final PeopleStore store;
  final AppSyncSession session;
  @override
  Future<void> pullAll() async {
    final timer = Stopwatch()..start();
    final runId = peopleOperationId();
    void trace(String event, Map<String, Object?> fields) => syncTrace(event, {
      'app': 'people',
      'run_id': runId,
      ...fields,
    }, sink: telemetry);
    trace('pull_started', {});
    try {
      final manifest = await session.manifest();
      if (manifest == null) {
        throw StateError('People synchronization is unavailable');
      }
      final manifestMs = timer.elapsedMilliseconds;
      final hashes = await store.hashes();
      final wanted = <int>{
        for (final entry in manifest.entries)
          if (hashes[entry['id']] != entry['hash']) entry['id'] as int,
      };
      trace('download_started', {
        'revision': manifest.revision,
        'root_hash': manifest.root,
        'record_count': wanted.length,
      });
      final downloadTimer = Stopwatch()..start();
      final items = await session.download(manifest, wanted);
      trace('download_finished', {
        'revision': manifest.revision,
        'root_hash': manifest.root,
        'record_count': items.length,
        'duration_ms': downloadTimer.elapsedMilliseconds,
      });
      final downloadedMs = timer.elapsedMilliseconds;
      await store.applySnapshot(items, {
        for (final entry in manifest.entries) entry['id'] as int,
      });
      await store.library.saveRemote(
        'people_state',
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
      trace('cache_applied', {
        'app': 'people',
        'revision': manifest.revision,
        'root_hash': manifest.root,
        'changed_count': wanted.length,
        'manifest_ms': manifestMs,
        'download_and_compare_ms': downloadedMs - manifestMs,
        'apply_ms': timer.elapsedMilliseconds - downloadedMs,
        'duration_ms': timer.elapsedMilliseconds,
      });
      await syncAssets?.call();
    } catch (error) {
      trace('pull_failed', {
        'duration_ms': timer.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
      });
      rethrow;
    }
  }

  @override
  Future<void> pullKeys(Set<int> keys) => pullAll();
}

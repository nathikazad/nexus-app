import 'dart:async';

import 'package:nx_notes/application/ports/clock.dart' as clock_port;
import 'package:nx_notes/application/ports/id_generator.dart' as id_port;
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/application/sync/notes_sync_engine.dart';
import 'package:nx_notes/data/sync/notes_document_collection_adapter.dart';
import 'package:nx_notes/data/sync/notes_push_conflict_resolver.dart';
import 'package:nx_notes/data/sync/notes_sync_store_adapter.dart';
import 'package:nx_notes/data/sync/notes_sync_transport.dart';
import 'package:nx_notes/domain/sync/sync_status.dart' as notes_status;
import 'package:nx_offline/nx_offline.dart' as offline;

/// Adapts the Notes-facing synchronization interface while delegating all
/// orchestration to the reusable `nx_offline` coordinator.
final class NxOfflineNotesSyncEngine implements NotesSyncEngine {
  factory NxOfflineNotesSyncEngine({
    required LocalNotesStore localStore,
    required RemoteDocumentGateway remoteGateway,
    required offline.AccountScope account,
    required clock_port.Clock clock,
    required id_port.IdGenerator idGenerator,
  }) {
    final store = NotesSyncStoreAdapter(delegate: localStore, account: account);
    final collection = NotesDocumentCollectionAdapter(
      localStore: localStore,
      account: account,
      clock: clock,
    );
    final coordinator = offline.SyncCoordinator(
      store: store,
      transport: NotesSyncTransport(
        localStore: localStore,
        remoteGateway: remoteGateway,
        account: account,
      ),
      collections: [collection],
      pushConflictResolvers: [
        NotesPushConflictResolver(
          localStore: localStore,
          remoteGateway: remoteGateway,
          clock: clock,
          account: account,
        ),
      ],
      clock: _OfflineClock(clock),
      idGenerator: _OfflineIdGenerator(idGenerator),
    );
    return NxOfflineNotesSyncEngine._(coordinator);
  }

  NxOfflineNotesSyncEngine._(this._coordinator);

  final offline.SyncCoordinator _coordinator;
  Future<SyncRunResult>? _activeRun;

  @override
  notes_status.SyncStatus get status => _toNotesStatus(_coordinator.status);

  @override
  Stream<notes_status.SyncStatus> get statusChanges =>
      _coordinator.statusChanges.map(_toNotesStatus);

  @override
  Future<SyncRunResult> synchronize({SyncReason reason = SyncReason.manual}) {
    final active = _activeRun;
    if (active != null) return active;
    final run = _coordinator
        .synchronize(reason: offline.SyncReason.values.byName(reason.name))
        .then(
          (result) => SyncRunResult(
            pushedCount: result.pushedCount,
            pulledCount: result.pulledCount,
            conflictCount: result.conflictCount,
            failureCount: result.failureCount,
          ),
        );
    _activeRun = run;
    unawaited(
      run.then<void>(
        (_) {
          if (identical(_activeRun, run)) _activeRun = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_activeRun, run)) _activeRun = null;
        },
      ),
    );
    return run;
  }

  @override
  Future<void> dispose() => _coordinator.dispose();
}

notes_status.SyncStatus _toNotesStatus(offline.SyncStatus status) {
  return notes_status.SyncStatus(
    activity: switch (status.activity) {
      offline.SyncActivity.idle => notes_status.SyncActivity.idle,
      offline.SyncActivity.syncing => notes_status.SyncActivity.syncing,
      offline.SyncActivity.retryWaiting =>
        notes_status.SyncActivity.retryWaiting,
      offline.SyncActivity.blocked => notes_status.SyncActivity.blocked,
    },
    pendingCount: status.pendingCount,
    lastSyncedAt: status.lastSyncedAt,
    message: status.message,
  );
}

final class _OfflineClock implements offline.Clock {
  const _OfflineClock(this.delegate);

  final clock_port.Clock delegate;

  @override
  DateTime now() => delegate.now();
}

final class _OfflineIdGenerator implements offline.IdGenerator {
  const _OfflineIdGenerator(this.delegate);

  final id_port.IdGenerator delegate;

  @override
  String nextId() => delegate.nextId();
}

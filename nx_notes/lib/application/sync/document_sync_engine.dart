import 'dart:async';

import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/application/sync/conflict_detector.dart';
import 'package:nx_notes/application/sync/retry_policy.dart';
import 'package:nx_notes/domain/sync/local_document.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_conflict.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';
import 'package:nx_notes/domain/sync/sync_status.dart';

enum SyncReason { manual, appStarted, connectivityRestored, timer }

class SyncRunResult {
  const SyncRunResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.conflictCount,
    required this.failureCount,
  });

  final int pushedCount;
  final int pulledCount;
  final int conflictCount;
  final int failureCount;

  bool get succeeded => failureCount == 0 && conflictCount == 0;
}

/// Coordinates local and remote ports without depending on either adapter.
///
/// A run pushes the durable outbox before pulling remote changes. Concurrent
/// callers share the same run, so lifecycle and connectivity triggers cannot
/// race each other.
class DocumentSyncEngine {
  DocumentSyncEngine({
    required this.localStore,
    required this.remoteGateway,
    required this.clock,
    required this.idGenerator,
    this.retryPolicy = const RetryPolicy(),
    this.pullResolutionPolicy = const PullResolutionPolicy(),
    this.operationLease = const Duration(minutes: 1),
  });

  final LocalNotesStore localStore;
  final RemoteDocumentGateway remoteGateway;
  final Clock clock;
  final IdGenerator idGenerator;
  final RetryPolicy retryPolicy;
  final PullResolutionPolicy pullResolutionPolicy;
  final Duration operationLease;

  final StreamController<SyncStatus> _statusChanges =
      StreamController<SyncStatus>.broadcast();
  Future<SyncRunResult>? _activeRun;
  SyncStatus _status = const SyncStatus.idle();

  SyncStatus get status => _status;
  Stream<SyncStatus> get statusChanges => _statusChanges.stream;

  Future<SyncRunResult> synchronize({SyncReason reason = SyncReason.manual}) {
    final active = _activeRun;
    if (active != null) return active;
    final run = _run(reason);
    _activeRun = run;
    run.whenComplete(() {
      if (identical(_activeRun, run)) _activeRun = null;
    });
    return run;
  }

  Future<void> dispose() => _statusChanges.close();

  Future<SyncRunResult> _run(SyncReason reason) async {
    final workerId = 'sync-${idGenerator.nextId()}';
    var pushed = 0;
    var pulled = 0;
    var conflicts = 0;
    var failures = 0;
    var authenticationBlocked = false;

    await _emitStatus(SyncActivity.syncing);

    while (true) {
      final operation = await localStore.claimNextOperation(
        workerId: workerId,
        lease: operationLease,
        now: clock.now(),
      );
      if (operation == null) break;

      try {
        final result = await _push(operation);
        await localStore.completeOperation(
          operation.operationId,
          result: result,
        );
        pushed++;
      } on RemoteGatewayException catch (error) {
        failures++;
        if (error.failure.kind == SyncFailureKind.conflict) {
          if (await _recordPushConflict(operation)) conflicts++;
        }
        final retryAt = error.failure.isRetryable
            ? retryPolicy.retryAt(clock.now(), operation.attemptCount + 1)
            : clock.now().add(const Duration(days: 36500));
        await localStore.failOperation(
          operation.operationId,
          failure: error.failure,
          retryAt: retryAt,
        );
        if (error.failure.kind == SyncFailureKind.authentication) {
          authenticationBlocked = true;
          break;
        }
      } catch (error) {
        failures++;
        final failure = SyncFailure(
          kind: SyncFailureKind.unknown,
          message: error.toString(),
        );
        await localStore.failOperation(
          operation.operationId,
          failure: failure,
          retryAt: retryPolicy.retryAt(clock.now(), operation.attemptCount + 1),
        );
      }
    }

    if (!authenticationBlocked) {
      try {
        final pullResult = await _pull();
        pulled += pullResult.imported;
        conflicts += pullResult.conflicts;
      } on RemoteGatewayException catch (error) {
        failures++;
        authenticationBlocked =
            error.failure.kind == SyncFailureKind.authentication;
      } catch (_) {
        failures++;
      }
    }

    final pending = await localStore.pendingOperations();
    final activity = authenticationBlocked
        ? SyncActivity.blocked
        : pending.isNotEmpty || failures > 0
        ? SyncActivity.retryWaiting
        : SyncActivity.idle;
    _setStatus(
      SyncStatus(
        activity: activity,
        pendingCount: pending.length,
        lastSyncedAt: activity == SyncActivity.idle ? clock.now() : null,
        message: authenticationBlocked
            ? 'Authentication is required before syncing can continue.'
            : failures > 0
            ? 'Some changes could not be synchronized.'
            : conflicts > 0
            ? 'Some documents need conflict resolution.'
            : null,
      ),
    );
    return SyncRunResult(
      pushedCount: pushed,
      pulledCount: pulled,
      conflictCount: conflicts,
      failureCount: failures,
    );
  }

  Future<RemoteWriteResult> _push(PendingOperation operation) async {
    final local = await localStore.getDocument(operation.documentKey);
    if (local == null) {
      throw const RemoteGatewayException(
        SyncFailure(
          kind: SyncFailureKind.validation,
          message: 'local document does not exist',
        ),
      );
    }
    return switch (operation.type) {
      PendingOperationType.create => remoteGateway.createDocument(
        RemoteCreateRequest(key: local.key, document: local.document),
        idempotencyKey: operation.operationId,
      ),
      PendingOperationType.update => remoteGateway.updateDocument(
        RemoteUpdateRequest(key: local.key, document: local.document),
        idempotencyKey: operation.operationId,
        expectedRevision:
            operation.baseRevision ??
            local.baseServerRevision ??
            (throw const RemoteGatewayException(
              SyncFailure(
                kind: SyncFailureKind.validation,
                message: 'update is missing its base remote revision',
              ),
            )),
      ),
      PendingOperationType.delete => remoteGateway.deleteDocument(
        RemoteDeleteRequest(key: local.key),
        idempotencyKey: operation.operationId,
        expectedRevision:
            operation.baseRevision ??
            local.baseServerRevision ??
            (throw const RemoteGatewayException(
              SyncFailure(
                kind: SyncFailureKind.validation,
                message: 'delete is missing its base remote revision',
              ),
            )),
      ),
    };
  }

  Future<bool> _recordPushConflict(PendingOperation operation) async {
    final local = await localStore.getDocument(operation.documentKey);
    if (local == null) return false;
    final changes = await remoteGateway.pullChanges(cursor: null);
    final remote = _findRemote(changes.documents, local);
    if (remote == null) return false;
    await _recordConflict(local, remote);
    return true;
  }

  Future<({int imported, int conflicts})> _pull() async {
    final cursor = await localStore.readSyncCursor();
    final changes = await remoteGateway.pullChanges(cursor: cursor);
    final imports = <RemoteDocument>[];
    var conflicts = 0;

    for (final remote in changes.documents) {
      final local = await localStore.getDocument(remote.key);
      final resolution = pullResolutionPolicy.resolve(
        localExists: local != null,
        localState: local?.syncState,
        baseRevision: local?.baseServerRevision,
        incomingRevision: remote.revision,
      );
      switch (resolution) {
        case PullResolution.insertRemote:
        case PullResolution.replaceLocal:
          imports.add(remote);
        case PullResolution.keepLocal:
          break;
        case PullResolution.conflict:
          await _recordConflict(local!, remote);
          conflicts++;
      }
    }

    if (imports.isNotEmpty) {
      await localStore.importRemoteDocuments(imports);
    }
    await localStore.writeSyncCursor(changes.nextCursor);
    return (imported: imports.length, conflicts: conflicts);
  }

  RemoteDocument? _findRemote(
    List<RemoteDocument> documents,
    LocalDocument local,
  ) {
    for (final remote in documents) {
      if (remote.key.localId == local.key.localId ||
          (local.key.remoteId != null &&
              remote.key.remoteId == local.key.remoteId)) {
        return remote;
      }
    }
    return null;
  }

  Future<void> _recordConflict(LocalDocument local, RemoteDocument remote) {
    return localStore.recordConflict(
      SyncConflict(
        documentKey: local.key,
        localDocument: local.document,
        remoteDocument: remote.document,
        remoteRevision: remote.revision,
        detectedAt: clock.now(),
      ),
    );
  }

  Future<void> _emitStatus(SyncActivity activity) async {
    final pending = await localStore.pendingOperations();
    _setStatus(SyncStatus(activity: activity, pendingCount: pending.length));
  }

  void _setStatus(SyncStatus status) {
    _status = status;
    if (!_statusChanges.isClosed) _statusChanges.add(status);
  }
}

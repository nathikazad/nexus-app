import 'dart:async';

import 'package:nx_docs/sync/native/document_outbox.dart';
import 'package:nx_docs/sync/clock.dart';
import 'package:nx_docs/sync/native/local_notes_store.dart';
import 'package:nx_docs/sync/remote/document_remote_api.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

enum BackgroundUploadActivity { idle, uploading, retryWaiting }

final class BackgroundUploadState {
  const BackgroundUploadState({
    this.activity = BackgroundUploadActivity.idle,
    this.pendingCount = 0,
    this.lastUploadedAt,
    this.error,
  });

  final BackgroundUploadActivity activity;
  final int pendingCount;
  final DateTime? lastUploadedAt;
  final Object? error;
}

/// Documents-facing facade over the shared nx_offline outbox runtime.
final class BackgroundUploader {
  BackgroundUploader({
    required LocalNotesStore localStore,
    required DocumentRemoteApi remoteApi,
    required Clock clock,
    required String workerId,
    this.uploadDelay = const Duration(seconds: 2),
    this.lease = const Duration(minutes: 1),
    this.retryPolicy = const offline.RetryPolicy(),
    offline.AccountIdentity? account,
  }) {
    final sharedClock = _SharedClock(clock);
    _processor = offline.OutboxProcessor(
      store: DocumentOutboxStoreAdapter(
        localStore: localStore,
        account:
            account ??
            offline.AccountIdentity(
              serverId: 'nexus-primary',
              userId: _userId(localStore.accountKey),
              application: 'nx_notes',
            ),
      ),
      handlers: <offline.MutationHandler>[
        DocumentMutationHandler(localStore: localStore, remoteApi: remoteApi),
      ],
      clock: sharedClock,
      workerId: workerId,
      scheduler: offline.RetryScheduler(clock: sharedClock),
      retryPolicy: retryPolicy,
      operationLease: lease,
    );
    _statusSubscription = _processor.statusChanges.listen(_applyStatus);
  }

  final Duration uploadDelay;
  final Duration lease;
  final offline.RetryPolicy retryPolicy;
  final StreamController<BackgroundUploadState> _states =
      StreamController<BackgroundUploadState>.broadcast(sync: true);
  late final offline.OutboxProcessor _processor;
  late final StreamSubscription<offline.SyncStatus> _statusSubscription;
  BackgroundUploadState _state = const BackgroundUploadState();
  bool _closed = false;

  BackgroundUploadState get state => _state;
  Stream<BackgroundUploadState> get states => _states.stream;

  void schedule() {
    if (_closed) return;
    _processor.schedule(delay: uploadDelay);
  }

  Future<void> uploadPending() async {
    if (_closed) return;
    await _processor.process();
  }

  void _applyStatus(offline.SyncStatus status) {
    final activity = switch (status.activity) {
      offline.SyncActivity.idle => BackgroundUploadActivity.idle,
      offline.SyncActivity.syncing => BackgroundUploadActivity.uploading,
      offline.SyncActivity.retryWaiting ||
      offline.SyncActivity.blocked => BackgroundUploadActivity.retryWaiting,
    };
    _state = BackgroundUploadState(
      activity: activity,
      pendingCount: status.pendingCount,
      lastUploadedAt: status.lastSyncedAt ?? _state.lastUploadedAt,
      error: status.message,
    );
    if (!_closed) _states.add(_state);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _statusSubscription.cancel();
    await _processor.close();
    await _states.close();
  }

  static String _userId(String accountKey) {
    const prefix = 'user:';
    return accountKey.startsWith(prefix)
        ? accountKey.substring(prefix.length)
        : accountKey;
  }
}

final class _SharedClock implements offline.Clock {
  const _SharedClock(this.clock);

  final Clock clock;

  @override
  DateTime now() => clock.now();
}

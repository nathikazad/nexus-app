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

abstract interface class NotesSyncEngine {
  SyncStatus get status;

  Stream<SyncStatus> get statusChanges;

  Future<SyncRunResult> synchronize({SyncReason reason = SyncReason.manual});

  Future<void> dispose();
}

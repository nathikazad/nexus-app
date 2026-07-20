import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';

class ConflictDetector {
  const ConflictDetector();

  bool hasConflict({
    required DocumentSyncState localState,
    required RemoteRevision? baseRevision,
    required RemoteRevision incomingRevision,
  }) {
    final isLocallyDirty = localState != DocumentSyncState.synced;
    if (!isLocallyDirty) return false;
    if (baseRevision == null) return true;
    return baseRevision != incomingRevision;
  }
}

enum PullResolution { insertRemote, replaceLocal, keepLocal, conflict }

class PullResolutionPolicy {
  const PullResolutionPolicy({
    this.conflictDetector = const ConflictDetector(),
  });

  final ConflictDetector conflictDetector;

  PullResolution resolve({
    required bool localExists,
    required DocumentSyncState? localState,
    required RemoteRevision? baseRevision,
    required RemoteRevision incomingRevision,
  }) {
    if (!localExists) return PullResolution.insertRemote;
    if (localState == DocumentSyncState.synced) {
      return PullResolution.replaceLocal;
    }
    if (conflictDetector.hasConflict(
      localState: localState!,
      baseRevision: baseRevision,
      incomingRevision: incomingRevision,
    )) {
      return PullResolution.conflict;
    }
    return PullResolution.keepLocal;
  }
}

import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/data/sync/notes_sync_store_adapter.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/sync_conflict.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

/// Materializes the remote side of a conflict discovered while pushing a
/// conditional Notes mutation.
final class NotesPushConflictResolver implements offline.PushConflictResolver {
  const NotesPushConflictResolver({
    required this.localStore,
    required this.remoteGateway,
    required this.clock,
    required this.account,
  });

  final LocalNotesStore localStore;
  final RemoteDocumentGateway remoteGateway;
  final Clock clock;
  final offline.AccountScope account;

  @override
  String get collectionName => notesDocumentCollection;

  @override
  Future<void> resolvePushConflict({
    required offline.PendingMutation mutation,
    required offline.SyncFailure failure,
  }) async {
    if (mutation.collection != collectionName) {
      throw StateError('unsupported Notes collection: ${mutation.collection}');
    }
    if (mutation.account != account) {
      throw StateError('mutation belongs to another account');
    }
    if (failure.kind != offline.SyncFailureKind.conflict) {
      throw StateError('resolver requires a conflict failure');
    }

    final key = DocumentKey(
      localId: mutation.entityKey.localId,
      remoteId: mutation.entityKey.remoteId,
    );
    final local = await localStore.getDocument(key);
    if (local == null) return;

    final changes = await remoteGateway.pullChanges(cursor: null);
    final remote = changes.documents.where((candidate) {
      return candidate.key.localId == key.localId ||
          (key.remoteId != null && candidate.key.remoteId == key.remoteId);
    }).firstOrNull;
    if (remote == null) return;

    await localStore.recordConflict(
      SyncConflict(
        documentKey: local.key,
        localDocument: local.document,
        remoteDocument: remote.document,
        remoteRevision: remote.revision,
        detectedAt: clock.now(),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

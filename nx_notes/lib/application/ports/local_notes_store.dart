import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/sync/local_document.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';
import 'package:nx_notes/domain/sync/sync_conflict.dart';

abstract interface class LocalNotesStore {
  String get accountKey;

  Stream<List<LocalDocument>> watchDocuments(DocumentQuery query);

  Stream<LocalDocument?> watchDocument(DocumentKey key);

  Future<LocalDocument?> getDocument(DocumentKey key);

  Future<void> importRemoteDocuments(List<RemoteDocument> documents);

  Future<void> saveDraftAndEnqueue(
    LocalDocument document, {
    required PendingOperation operation,
  });

  Future<List<PendingOperation>> pendingOperations();

  Future<PendingOperation?> claimNextOperation({
    required String workerId,
    required Duration lease,
    required DateTime now,
  });

  Future<void> completeOperation(
    String operationId, {
    required RemoteWriteResult result,
  });

  Future<void> failOperation(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  });

  Future<String?> readSyncCursor();

  Future<void> writeSyncCursor(String cursor);

  Future<void> recordConflict(SyncConflict conflict);

  Future<List<SyncConflict>> conflicts();
}

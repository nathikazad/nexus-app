import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/document/document_summary.dart';
import 'package:nx_notes/domain/sync/local_document.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';

abstract interface class LocalNotesStore {
  String get accountKey;

  Stream<List<DocumentSummary>> watchCatalog(CatalogQuery query);

  Future<List<DocumentSummary>> readCatalog(CatalogQuery query);

  Future<void> replaceCatalog(
    CatalogQuery query,
    List<DocumentSummary> summaries,
  );

  Stream<LocalDocument?> watchDocument(DocumentKey key);

  Future<LocalDocument?> getDocument(DocumentKey key);

  Future<LocalDocument?> getDocumentByRemoteId(int remoteId);

  Future<void> importRemoteDocuments(List<RemoteDocument> documents);

  /// Replaces a stale local draft with the accepted remote document and
  /// removes pending work for that document in one transaction.
  Future<void> discardPendingAndImportRemote(RemoteDocument document);

  /// Applies a stale response only if [operationId] is still the current
  /// pending mutation. Returns false when a newer edit replaced it in flight.
  Future<bool> discardStaleOperationAndImportRemote(
    String operationId,
    RemoteDocument document,
  );

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

  Future<void> completeCreateOperation(
    String operationId, {
    required RemoteDocument document,
  });

  Future<void> failOperation(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  });
}

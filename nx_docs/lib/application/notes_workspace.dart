import 'package:nx_docs/application/document_session.dart';
import 'package:nx_docs/domain/catalog/catalog_query.dart';
import 'package:nx_docs/domain/catalog/catalog_state.dart';
import 'package:nx_docs/domain/document/document.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

abstract interface class NotesWorkspace {
  Stream<CatalogState> watchCatalog(CatalogQuery query);

  Future<void> refreshCatalog(CatalogQuery query);

  DocumentSession openDocument(int documentId);

  /// Requests fresh remote state for a user-visible document.
  ///
  /// Opening or observing a session alone never implies network I/O.
  Future<void> ensureDocumentAvailable(int documentId);

  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  });

  Future<void> deleteDocument(int documentId);

  Future<void> uploadPending();

  /// Reconciles the complete native cache. Web implementations may refresh
  /// their visible network-backed catalogs instead.
  Future<void> syncLibrary({
    offline.SyncReason reason = offline.SyncReason.manual,
  });

  Future<void> close();
}

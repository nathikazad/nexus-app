import 'package:nx_notes/application/document_session.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/catalog/catalog_state.dart';
import 'package:nx_notes/domain/document/document.dart';

abstract interface class NotesWorkspace {
  Stream<CatalogState> watchCatalog(CatalogQuery query);

  Future<void> refreshCatalog(CatalogQuery query);

  DocumentSession openDocument(int documentId);

  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  });

  Future<void> deleteDocument(int documentId);

  Future<void> uploadPending();

  /// Reconciles the complete native cache. Web implementations may refresh
  /// their visible network-backed catalogs instead.
  Future<void> syncLibrary();

  Future<void> close();
}

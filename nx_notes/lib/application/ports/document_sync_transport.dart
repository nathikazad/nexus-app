import 'package:nx_notes/domain/sync/document_sync.dart';

abstract interface class DocumentSyncTransport {
  Future<DocumentSyncBundle> syncDocuments({
    required List<DocumentManifestEntry> manifest,
    Set<int>? documentIds,
  });
}

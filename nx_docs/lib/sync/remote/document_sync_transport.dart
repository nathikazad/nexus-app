import 'package:nx_docs/sync/sync_models.dart';

abstract interface class DocumentSyncTransport {
  Future<DocumentSyncBundle> syncDocuments({
    required List<DocumentManifestEntry> manifest,
    Set<int>? documentIds,
  });
}

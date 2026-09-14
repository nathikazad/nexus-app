import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/documents.dart' as document_api;
import 'package:nx_db/kgql.dart';
import 'package:nx_docs/sync/remote/document_sync_transport.dart';
import 'package:nx_docs/documents/data/kgql/document_mapper.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/sync_models.dart';

final class KgqlDocumentSyncTransport implements DocumentSyncTransport {
  const KgqlDocumentSyncTransport(this._client);

  final GraphQLClient _client;

  @override
  Future<DocumentSyncBundle> syncDocuments({
    required List<DocumentManifestEntry> manifest,
    Set<int>? documentIds,
    bool manifestOnly = false,
  }) async {
    final response = await document_api.syncDocuments(
      _client,
      manifest: <Map<String, Object?>>[
        for (final entry in manifest) entry.toJson(),
      ],
      documentIds: documentIds,
      manifestOnly: manifestOnly,
      requestTimeout: document_api.documentBulkSyncTimeout,
    );
    return DocumentSyncBundle(
      manifest: [
        for (final entry in response.manifest)
          DocumentManifestEntry(documentId: entry.id, serverHash: entry.hash),
      ],
      documents: <RemoteDocument>[
        for (final entry in response.documents) _remoteDocument(entry),
      ],
      deletedIds: response.deletedIds,
    );
  }

  RemoteDocument _remoteDocument(document_api.DocumentSyncEntry entry) {
    final document = documentFromModel(Model.fromJson(entry.document));
    return RemoteDocument(
      key: DocumentKey(
        localId: 'remote-${entry.documentId}',
        remoteId: entry.documentId,
      ),
      document: document,
      revision: RemoteRevision(document.updatedAt.toUtc().toIso8601String()),
      serverHash: entry.syncHash,
    );
  }
}

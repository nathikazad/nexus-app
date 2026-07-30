import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/documents.dart' as document_api;
import 'package:nx_db/kgql.dart';
import 'package:nx_notes/application/ports/document_sync_transport.dart';
import 'package:nx_notes/data/document/document_mapper.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/document_sync.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';

final class KgqlDocumentSyncTransport implements DocumentSyncTransport {
  const KgqlDocumentSyncTransport(this._client);

  final GraphQLClient _client;

  @override
  Future<DocumentSyncBundle> syncDocuments({
    required List<DocumentManifestEntry> manifest,
    Set<int>? documentIds,
  }) async {
    final response = await document_api.syncDocuments(
      _client,
      manifest: <Map<String, Object?>>[
        for (final entry in manifest) entry.toJson(),
      ],
      documentIds: documentIds,
    );
    return DocumentSyncBundle(
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

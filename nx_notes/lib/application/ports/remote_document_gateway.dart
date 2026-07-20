import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';

class RemoteCreateRequest {
  const RemoteCreateRequest({required this.key, required this.document});

  final DocumentKey key;
  final NxDocument document;
}

class RemoteUpdateRequest {
  const RemoteUpdateRequest({required this.key, required this.document});

  final DocumentKey key;
  final NxDocument document;
}

class RemoteChangeSet {
  const RemoteChangeSet({required this.documents, required this.nextCursor});

  final List<RemoteDocument> documents;
  final String nextCursor;
}

class RemoteGatewayException implements Exception {
  const RemoteGatewayException(this.failure);

  final SyncFailure failure;

  @override
  String toString() =>
      'RemoteGatewayException(${failure.kind}: ${failure.message})';
}

abstract interface class RemoteDocumentGateway {
  Future<RemoteChangeSet> pullChanges({required String? cursor});

  Future<RemoteWriteResult> createDocument(
    RemoteCreateRequest request, {
    required String idempotencyKey,
  });

  Future<RemoteWriteResult> updateDocument(
    RemoteUpdateRequest request, {
    required String idempotencyKey,
    required RemoteRevision expectedRevision,
  });
}

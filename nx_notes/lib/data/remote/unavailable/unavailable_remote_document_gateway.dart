import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';

class UnavailableRemoteDocumentGateway implements RemoteDocumentGateway {
  const UnavailableRemoteDocumentGateway();

  Never _offline() {
    throw const RemoteGatewayException(
      SyncFailure(
        kind: SyncFailureKind.transient,
        message: 'backend is currently unreachable',
      ),
    );
  }

  @override
  Future<RemoteWriteResult> createDocument(
    RemoteCreateRequest request, {
    required String idempotencyKey,
  }) async => _offline();

  @override
  Future<RemoteWriteResult> deleteDocument(
    RemoteDeleteRequest request, {
    required String idempotencyKey,
    required RemoteRevision expectedRevision,
  }) async => _offline();

  @override
  Future<RemoteChangeSet> pullChanges({required String? cursor}) async =>
      _offline();

  @override
  Future<RemoteWriteResult> updateDocument(
    RemoteUpdateRequest request, {
    required String idempotencyKey,
    required RemoteRevision expectedRevision,
  }) async => _offline();
}

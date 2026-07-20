import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_repository.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';

class KgqlRemoteDocumentGateway implements RemoteDocumentGateway {
  KgqlRemoteDocumentGateway({required DocumentRepository repository})
    : _repository = repository;

  final DocumentRepository _repository;
  final Map<String, RemoteWriteResult> _operationResults =
      <String, RemoteWriteResult>{};
  final Map<int, String> _localIdsByRemoteId = <int, String>{};

  @override
  Future<RemoteWriteResult> createDocument(
    RemoteCreateRequest request, {
    required String idempotencyKey,
  }) async {
    final previous = _operationResults[idempotencyKey];
    if (previous != null) return previous;
    try {
      final created = await _repository.create(
        title: request.document.title,
        kind: request.document.isBook
            ? DocumentKind.book
            : DocumentKind.document,
      );
      final updated = await _repository.updateDraft(
        _copyDocument(request.document, id: created.id),
      );
      final key = request.key.withRemoteId(created.id);
      final result = RemoteWriteResult(
        key: key,
        revision: _revisionOf(updated),
      );
      _localIdsByRemoteId[created.id] = key.localId;
      _operationResults[idempotencyKey] = result;
      return result;
    } on RemoteGatewayException {
      rethrow;
    } catch (error) {
      throw RemoteGatewayException(
        SyncFailure(kind: SyncFailureKind.transient, message: '$error'),
      );
    }
  }

  @override
  Future<RemoteWriteResult> updateDocument(
    RemoteUpdateRequest request, {
    required String idempotencyKey,
    required RemoteRevision expectedRevision,
  }) async {
    final previous = _operationResults[idempotencyKey];
    if (previous != null) return previous;
    final remoteId = request.key.remoteId;
    if (remoteId == null) {
      throw const RemoteGatewayException(
        SyncFailure(
          kind: SyncFailureKind.validation,
          message: 'remote id required for update',
        ),
      );
    }
    try {
      final current = await _repository.getById(remoteId);
      if (current == null) {
        throw const RemoteGatewayException(
          SyncFailure(
            kind: SyncFailureKind.validation,
            message: 'remote document not found',
          ),
        );
      }
      if (_revisionOf(current) != expectedRevision) {
        throw const RemoteGatewayException(
          SyncFailure(
            kind: SyncFailureKind.conflict,
            message: 'stale document revision',
          ),
        );
      }
      final updated = await _repository.updateDraft(
        _copyDocument(request.document, id: remoteId),
      );
      final result = RemoteWriteResult(
        key: request.key,
        revision: _revisionOf(updated),
      );
      _localIdsByRemoteId[remoteId] = request.key.localId;
      _operationResults[idempotencyKey] = result;
      return result;
    } on RemoteGatewayException {
      rethrow;
    } catch (error) {
      throw RemoteGatewayException(
        SyncFailure(kind: SyncFailureKind.transient, message: '$error'),
      );
    }
  }

  @override
  Future<RemoteWriteResult> deleteDocument(
    RemoteDeleteRequest request, {
    required String idempotencyKey,
    required RemoteRevision expectedRevision,
  }) async {
    final previous = _operationResults[idempotencyKey];
    if (previous != null) return previous;
    final remoteId = request.key.remoteId;
    if (remoteId == null) {
      throw const RemoteGatewayException(
        SyncFailure(
          kind: SyncFailureKind.validation,
          message: 'remote id required for delete',
        ),
      );
    }
    try {
      final current = await _repository.getById(remoteId);
      if (current == null) {
        throw const RemoteGatewayException(
          SyncFailure(
            kind: SyncFailureKind.validation,
            message: 'remote document not found',
          ),
        );
      }
      if (_revisionOf(current) != expectedRevision) {
        throw const RemoteGatewayException(
          SyncFailure(
            kind: SyncFailureKind.conflict,
            message: 'stale document revision',
          ),
        );
      }
      await _repository.delete(remoteId);
      final result = RemoteWriteResult(
        key: request.key,
        revision: RemoteRevision('deleted:${expectedRevision.value}'),
      );
      _operationResults[idempotencyKey] = result;
      return result;
    } on RemoteGatewayException {
      rethrow;
    } catch (error) {
      throw RemoteGatewayException(
        SyncFailure(kind: SyncFailureKind.transient, message: '$error'),
      );
    }
  }

  @override
  Future<RemoteChangeSet> pullChanges({required String? cursor}) async {
    try {
      final after = cursor == null ? null : DateTime.tryParse(cursor)?.toUtc();
      final summaries = await _repository.listRecent(limit: 10000);
      final changed = summaries.where((document) {
        return after == null || document.updatedAt.toUtc().isAfter(after);
      }).toList();
      final documents = <RemoteDocument>[];
      for (final summary in changed) {
        final document = summary.hasFullDocument
            ? summary
            : await _repository.getById(summary.id);
        if (document == null) continue;
        documents.add(
          RemoteDocument(
            key: DocumentKey(
              localId:
                  _localIdsByRemoteId[document.id] ?? 'remote-${document.id}',
              remoteId: document.id,
            ),
            document: document,
            revision: _revisionOf(document),
          ),
        );
      }
      documents.sort(
        (a, b) => a.document.updatedAt.compareTo(b.document.updatedAt),
      );
      final latest = summaries.fold<DateTime?>(after, (current, document) {
        final value = document.updatedAt.toUtc();
        return current == null || value.isAfter(current) ? value : current;
      });
      return RemoteChangeSet(
        documents: documents,
        nextCursor:
            (latest ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
                .toIso8601String(),
      );
    } catch (error) {
      throw RemoteGatewayException(
        SyncFailure(kind: SyncFailureKind.transient, message: '$error'),
      );
    }
  }
}

RemoteRevision _revisionOf(NxDocument document) {
  return RemoteRevision(document.updatedAt.toUtc().toIso8601String());
}

NxDocument _copyDocument(NxDocument document, {required int id}) {
  return NxDocument(
    id: id,
    title: document.title,
    modelTypeName: document.modelTypeName,
    document: document.document,
    jsonDocument: document.jsonDocument,
    wordCount: document.wordCount,
    status: document.status,
    topics: document.topics,
    areaTags: document.areaTags,
    tagsBySystem: document.tagsBySystem,
    pinned: document.pinned,
    updatedAt: document.updatedAt,
    updatedLabel: document.updatedLabel,
    versionNumber: document.versionNumber,
    excerpt: document.excerpt,
    links: document.links,
    publish: document.publish,
    readingState: document.readingState,
    bookRank: document.bookRank,
  );
}

import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';

class FakeRemoteDocumentGateway implements RemoteDocumentGateway {
  FakeRemoteDocumentGateway({this.firstRemoteId = 1000});

  final int firstRemoteId;
  final Map<String, RemoteDocument> _documents = <String, RemoteDocument>{};
  final Map<String, RemoteWriteResult> _idempotentResults =
      <String, RemoteWriteResult>{};
  final List<RemoteGatewayException> _failures = <RemoteGatewayException>[];
  final List<RemoteGatewayException> _postCommitFailures =
      <RemoteGatewayException>[];
  var _nextRemoteIdOffset = 0;
  var _revision = 0;
  var createCalls = 0;
  var updateCalls = 0;

  List<RemoteDocument> get documents =>
      List<RemoteDocument>.unmodifiable(_documents.values);

  void seed(RemoteDocument document) {
    _documents[document.key.localId] = document;
    final parsed = int.tryParse(
      document.revision.value.replaceFirst('rev-', ''),
    );
    if (parsed != null && parsed > _revision) _revision = parsed;
  }

  void failNext(RemoteGatewayException exception) {
    _failures.add(exception);
  }

  /// Simulates a response being lost after the server durably applied a write.
  void failAfterNextCommit(RemoteGatewayException exception) {
    _postCommitFailures.add(exception);
  }

  @override
  Future<RemoteWriteResult> createDocument(
    RemoteCreateRequest request, {
    required String idempotencyKey,
  }) async {
    createCalls++;
    _throwQueuedFailure();
    final prior = _idempotentResults[idempotencyKey];
    if (prior != null) return prior;
    if (_documents.containsKey(request.key.localId)) {
      throw const RemoteGatewayException(
        SyncFailure(
          kind: SyncFailureKind.validation,
          message: 'document already exists',
        ),
      );
    }
    final key = request.key.withRemoteId(firstRemoteId + _nextRemoteIdOffset++);
    final revision = _nextRevision();
    final result = RemoteWriteResult(key: key, revision: revision);
    _documents[key.localId] = RemoteDocument(
      key: key,
      document: _withId(request.document, key.remoteId!),
      revision: revision,
    );
    _idempotentResults[idempotencyKey] = result;
    _throwPostCommitFailure();
    return result;
  }

  @override
  Future<RemoteWriteResult> updateDocument(
    RemoteUpdateRequest request, {
    required String idempotencyKey,
    required RemoteRevision expectedRevision,
  }) async {
    updateCalls++;
    _throwQueuedFailure();
    final prior = _idempotentResults[idempotencyKey];
    if (prior != null) return prior;
    final current = _documents[request.key.localId];
    if (current == null) {
      throw const RemoteGatewayException(
        SyncFailure(
          kind: SyncFailureKind.validation,
          message: 'document not found',
        ),
      );
    }
    if (current.revision != expectedRevision) {
      throw const RemoteGatewayException(
        SyncFailure(
          kind: SyncFailureKind.conflict,
          message: 'stale document revision',
        ),
      );
    }
    final revision = _nextRevision();
    final result = RemoteWriteResult(key: current.key, revision: revision);
    _documents[current.key.localId] = RemoteDocument(
      key: current.key,
      document: _withId(request.document, current.key.remoteId!),
      revision: revision,
    );
    _idempotentResults[idempotencyKey] = result;
    _throwPostCommitFailure();
    return result;
  }

  @override
  Future<RemoteChangeSet> pullChanges({required String? cursor}) async {
    _throwQueuedFailure();
    final after = cursor == null ? -1 : int.tryParse(cursor) ?? -1;
    final documents =
        _documents.values.where((document) {
          return _revisionNumber(document.revision) > after;
        }).toList()..sort(
          (a, b) => _revisionNumber(
            a.revision,
          ).compareTo(_revisionNumber(b.revision)),
        );
    return RemoteChangeSet(
      documents: documents,
      nextCursor: _revision.toString(),
    );
  }

  RemoteRevision _nextRevision() => RemoteRevision('rev-${++_revision}');

  int _revisionNumber(RemoteRevision revision) {
    return int.parse(revision.value.replaceFirst('rev-', ''));
  }

  void _throwQueuedFailure() {
    if (_failures.isEmpty) return;
    throw _failures.removeAt(0);
  }

  void _throwPostCommitFailure() {
    if (_postCommitFailures.isEmpty) return;
    throw _postCommitFailures.removeAt(0);
  }
}

NxDocument _withId(NxDocument document, int id) {
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

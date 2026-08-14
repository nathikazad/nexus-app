import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/sync_models.dart';

NxDocument offlineTestDocument({
  int id = 1,
  String title = 'Test document',
  String body = 'Test body',
  bool pinned = false,
  DateTime? updatedAt,
}) {
  final timestamp = updatedAt ?? DateTime.utc(2026, 1, 1);
  return NxDocument(
    id: id,
    title: title,
    modelTypeName: 'Document',
    document: body,
    jsonDocument: <String, Object?>{
      'format': 'appflowy_document',
      'document': <String, Object?>{'body': body},
    },
    wordCount: body.split(RegExp(r'\s+')).length,
    status: 'Draft',
    topics: const <String>[],
    areaTags: const <String>[],
    tagsBySystem: const <String, List<String>>{
      'Status': <String>['Draft'],
    },
    pinned: pinned,
    updatedAt: timestamp,
    updatedLabel: 'test',
    versionNumber: 0,
    excerpt: body,
    links: const [],
  );
}

LocalDocument offlineLocalDocument({
  String localId = 'local-1',
  int? remoteId = 1,
  String accountKey = 'prod:user-1',
  String title = 'Test document',
  String body = 'Test body',
  DocumentSyncState syncState = DocumentSyncState.locallyModified,
  RemoteRevision? serverRevision = const RemoteRevision('rev-1'),
  RemoteRevision? baseServerRevision = const RemoteRevision('rev-1'),
  DateTime? updatedAt,
}) {
  final timestamp = updatedAt ?? DateTime.utc(2026, 1, 1);
  return LocalDocument(
    key: DocumentKey(localId: localId, remoteId: remoteId),
    accountKey: accountKey,
    document: offlineTestDocument(
      id: remoteId ?? 0,
      title: title,
      body: body,
      updatedAt: timestamp,
    ),
    localUpdatedAt: timestamp,
    serverRevision: serverRevision,
    baseServerRevision: baseServerRevision,
    syncState: syncState,
  );
}

PendingOperation offlinePendingOperation({
  String operationId = 'operation-1',
  String localId = 'local-1',
  int? remoteId = 1,
  String accountKey = 'prod:user-1',
  PendingOperationType type = PendingOperationType.update,
  String body = 'Test body',
  RemoteRevision? baseRevision = const RemoteRevision('rev-1'),
  DateTime? createdAt,
}) {
  return PendingOperation(
    operationId: operationId,
    accountKey: accountKey,
    documentKey: DocumentKey(localId: localId, remoteId: remoteId),
    type: type,
    payload: <String, Object?>{'body': body},
    baseRevision: baseRevision,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  );
}

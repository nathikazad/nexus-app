import 'package:graphql_flutter/graphql_flutter.dart';

import '../core/client/db_audit_context.dart';
import '../kgql/requests/set_model_request.dart';

const String _mutateDocumentMutation = r'''
mutation MutateDocument(
  $data: JSON!
  $clientUpdatedAt: String
  $domainId: Int
) {
  mutateDocument(
    data: $data
    clientUpdatedAt: $clientUpdatedAt
    domainId: $domainId
  )
}
''';

const String _syncDocumentsQuery = r'''
query SyncDocuments(
  $manifest: JSON!
  $documentIds: [Int!]
  $domainId: Int
) {
  syncDocuments(
    manifest: $manifest
    documentIds: $documentIds
    domainId: $domainId
  )
}
''';

enum DocumentMutationStatus { applied, stale, deleted }

final class DocumentMutationResult {
  const DocumentMutationResult({
    required this.status,
    required this.documentId,
    this.updatedAt,
    this.syncHash,
    this.document,
  });

  final DocumentMutationStatus status;
  final int documentId;
  final DateTime? updatedAt;
  final String? syncHash;
  final Map<String, dynamic>? document;
}

final class DocumentSyncEntry {
  const DocumentSyncEntry({
    required this.documentId,
    required this.syncHash,
    required this.document,
  });

  final int documentId;
  final String syncHash;
  final Map<String, dynamic> document;
}

final class DocumentSyncResponse {
  const DocumentSyncResponse({
    required this.documents,
    required this.deletedIds,
  });

  final List<DocumentSyncEntry> documents;
  final List<int> deletedIds;
}

Future<DocumentMutationResult> mutateDocument(
  GraphQLClient client,
  SetModelRequest request, {
  DateTime? clientUpdatedAt,
  int? domainId,
  DbAuditContext? auditContext,
  String auditSourceKind = 'document',
}) {
  final context = auditContext ??
      currentDbAuditContext() ??
      DbAuditContext.create(
        sourceKind: auditSourceKind,
        sourceId: _sourceId(request),
        sourceLabel: request.name ?? 'Document mutation',
      );
  return runWithDbAuditContext(context, () async {
    final variables = <String, dynamic>{
      'data': request.toJson(),
      'clientUpdatedAt': clientUpdatedAt?.toUtc().toIso8601String(),
      if (domainId != null) 'domainId': domainId,
    };
    final result = await client.mutate(
      MutationOptions(
        document: gql(_mutateDocumentMutation),
        variables: variables,
      ),
    );
    if (result.hasException) throw result.exception!;

    final payload = _jsonMap(result.data?['mutateDocument']);
    final status = switch (payload['status']) {
      'APPLIED' => DocumentMutationStatus.applied,
      'STALE' => DocumentMutationStatus.stale,
      'DELETED' => DocumentMutationStatus.deleted,
      final Object? value => throw StateError(
          'Unknown mutateDocument status: $value',
        ),
    };
    final id = payload['id'];
    if (id is! int) {
      throw StateError('mutateDocument did not return an integer id');
    }
    return DocumentMutationResult(
      status: status,
      documentId: id,
      updatedAt: _parseTimestamp(payload['updated_at']),
      syncHash: payload['sync_hash'] as String?,
      document: _optionalJsonMap(payload['document']),
    );
  });
}

Future<DocumentSyncResponse> syncDocuments(
  GraphQLClient client, {
  required List<Map<String, Object?>> manifest,
  Set<int>? documentIds,
  int? domainId,
}) async {
  final sortedDocumentIds =
      documentIds == null ? null : (documentIds.toList()..sort());
  final result = await client.query(
    QueryOptions(
      document: gql(_syncDocumentsQuery),
      variables: <String, dynamic>{
        'manifest': manifest,
        'documentIds': sortedDocumentIds,
        if (domainId != null) 'domainId': domainId,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  if (result.hasException) throw result.exception!;

  final payload = _jsonMap(result.data?['syncDocuments']);
  final rawDocuments = payload['documents'];
  final rawDeletedIds = payload['deleted_ids'];
  if (rawDocuments is! List || rawDeletedIds is! List) {
    throw StateError('Invalid syncDocuments response: $payload');
  }
  return DocumentSyncResponse(
    documents: <DocumentSyncEntry>[
      for (final raw in rawDocuments)
        if (raw is Map) _syncEntry(Map<String, dynamic>.from(raw)),
    ],
    deletedIds: <int>[
      for (final value in rawDeletedIds)
        if (value is int) value,
    ],
  );
}

DocumentSyncEntry _syncEntry(Map<String, dynamic> json) {
  final id = json['id'];
  final hash = json['hash'];
  final document = json['document'];
  if (id is! int || hash is! String || document is! Map) {
    throw StateError('Invalid synchronized document: $json');
  }
  return DocumentSyncEntry(
    documentId: id,
    syncHash: hash,
    document: Map<String, dynamic>.from(document),
  );
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw StateError('Expected JSON object, received $value');
}

Map<String, dynamic>? _optionalJsonMap(Object? value) {
  if (value == null) return null;
  return _jsonMap(value);
}

DateTime? _parseTimestamp(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final hasTimeZone =
      value.endsWith('Z') || RegExp(r'[+-]\d\d(?::?\d\d)?$').hasMatch(value);
  return DateTime.parse(hasTimeZone ? value : '${value}Z').toUtc();
}

String _sourceId(SetModelRequest request) {
  if (request.id != null) return 'document:${request.id}';
  return 'document:create:${request.modelType ?? 'unknown'}';
}

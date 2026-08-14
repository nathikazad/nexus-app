import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/documents.dart' as document_api;
import 'package:nx_db/kgql.dart';
import 'package:nx_documents/documents/document_content.dart';

class KgqlDocumentContentRepository implements DocumentContentRepository {
  KgqlDocumentContentRepository({
    required GraphQLClient client,
    required this.auditSourceKind,
  }) : _client = client;

  static const _documentAttribute = 'document';
  static const _jsonDocumentAttribute = 'json_document';

  final GraphQLClient _client;
  final String auditSourceKind;

  @override
  Future<DocumentContent?> load(DocumentIdentity identity) async {
    final model = await fetchKgqlModelById(
      _client,
      modelTypeName: identity.modelType,
      id: identity.id,
      struct: const <String, dynamic>{
        'id': true,
        'name': true,
        'updated_at': true,
        'created_at': true,
        _documentAttribute: true,
        _jsonDocumentAttribute: true,
      },
    );
    if (model == null) return null;
    return _contentFromModel(identity, model);
  }

  @override
  Future<DocumentContent> save(DocumentContent content) async {
    final editedAt = _nextMutationTime(content.updatedAt);
    final result = await document_api.mutateDocument(
      _client,
      SetModelRequest(
        id: content.identity.id,
        attributes: <SetModelAttribute>[
          SetModelAttribute(key: _documentAttribute, value: content.plainText),
          SetModelAttribute(
            key: _jsonDocumentAttribute,
            value: content.jsonDocument,
          ),
        ],
      ),
      clientUpdatedAt: editedAt,
      auditSourceKind: auditSourceKind,
    );
    if (result.status == document_api.DocumentMutationStatus.stale) {
      throw StateError('The document changed on another device.');
    }
    return content.copyWith(updatedAt: result.updatedAt ?? editedAt);
  }
}

DocumentContent _contentFromModel(DocumentIdentity identity, Model model) {
  return DocumentContent(
    identity: identity,
    title: model.name,
    plainText: model.attrString('document') ?? '',
    jsonDocument: _jsonMap(model.attributes?['json_document']),
    updatedAt:
        DateTime.tryParse(model.updatedAt ?? '') ??
        DateTime.tryParse(model.createdAt ?? '') ??
        DateTime.now().toUtc(),
  );
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return const <String, dynamic>{};
}

DateTime _nextMutationTime(DateTime previous) {
  final now = DateTime.now().toUtc();
  return now.isAfter(previous.toUtc())
      ? now
      : previous.toUtc().add(const Duration(microseconds: 1));
}

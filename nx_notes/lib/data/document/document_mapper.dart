import 'dart:convert';

import 'package:nx_db/kgql.dart';
import 'package:nx_notes/data/document/document_attr_keys.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_publish.dart';
import 'package:nx_notes/domain/document/document_repository.dart';
import 'package:nx_notes/domain/document/document_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';

NxDocument documentFromModel(Model model, {int versionNumber = 0}) {
  final document = model.attrString(kDocumentAttrDocument) ?? '';
  final jsonDocument = _jsonMap(model.attributes?[kDocumentAttrJsonDocument]);
  final publish = DocumentPublishState.fromJson(
    model.attributes?[kDocumentAttrPublish],
  );
  final updatedAt =
      DateTime.tryParse(model.updatedAt ?? '') ??
      DateTime.tryParse(model.createdAt ?? '') ??
      DateTime.now();
  final tags = model.tags ?? const <String, List<String>>{};
  final topics = List<String>.from(tags[kDocumentTopicTagSystem] ?? const []);
  final areaTags = List<String>.from(tags[kDocumentAreaTagSystem] ?? const []);
  final statusTags = tags[kDocumentStatusTagSystem] ?? const [];
  return NxDocument(
    id: model.id,
    title: model.name,
    modelTypeName: model.modelType?.name ?? '',
    document: document,
    jsonDocument: jsonDocument,
    wordCount: _countWords(document),
    status: statusTags.isEmpty ? 'Draft' : statusTags.first,
    topics: topics,
    areaTags: areaTags,
    tagsBySystem: {
      for (final entry in tags.entries)
        entry.key: List<String>.from(entry.value),
    },
    pinned: model.attrBool(kDocumentAttrPinned) ?? false,
    updatedAt: updatedAt,
    updatedLabel: _relativeLabel(updatedAt),
    versionNumber: versionNumber,
    excerpt: _excerptFrom(document),
    links: _linksFromModel(model),
    publish: publish,
    readingState: model.attrString(kBookAttrReadingState) ?? '',
    bookRank: model.attrInt(kBookAttrRank),
  );
}

NxDocument documentSummaryFromModel(Model model) {
  final updatedAt =
      DateTime.tryParse(model.updatedAt ?? '') ??
      DateTime.tryParse(model.createdAt ?? '') ??
      DateTime.now();
  final tags = model.tags ?? const <String, List<String>>{};
  final topics = List<String>.from(tags[kDocumentTopicTagSystem] ?? const []);
  final areaTags = List<String>.from(tags[kDocumentAreaTagSystem] ?? const []);
  final statusTags = tags[kDocumentStatusTagSystem] ?? const [];
  final excerpt = model.description?.trim() ?? '';
  return NxDocument(
    id: model.id,
    title: model.name,
    modelTypeName: model.modelType?.name ?? '',
    document: '',
    jsonDocument: const <String, dynamic>{},
    wordCount: model.attrInt(kDocumentAttrWordCount) ?? 0,
    status: statusTags.isEmpty ? 'Draft' : statusTags.first,
    topics: topics,
    areaTags: areaTags,
    tagsBySystem: {
      for (final entry in tags.entries)
        entry.key: List<String>.from(entry.value),
    },
    pinned: model.attrBool(kDocumentAttrPinned) ?? false,
    updatedAt: updatedAt,
    updatedLabel: _relativeLabel(updatedAt),
    versionNumber: 0,
    excerpt: excerpt,
    links: const <LinkedModel>[],
    publish: DocumentPublishState.fromJson(
      model.attributes?[kDocumentAttrPublish],
    ),
    readingState: model.attrString(kBookAttrReadingState) ?? '',
    bookRank: model.attrInt(kBookAttrRank),
  );
}

DocumentSnap documentSnapFromModel(Model model, {required int documentId}) {
  final document = model.attrString(kDocumentAttrDocument) ?? '';
  final createdAt = DateTime.tryParse(model.createdAt ?? '') ?? DateTime.now();
  return DocumentSnap(
    id: model.id,
    documentId: documentId,
    name: model.name,
    versionNumber: model.attrInt(kDocumentSnapAttrVersionNumber) ?? 0,
    document: document,
    jsonDocument: _jsonMap(model.attributes?[kDocumentAttrJsonDocument]),
    source: model.attrString(kDocumentSnapAttrSource) ?? '',
    changeSummary: _changeSummaryLabel(
      model.attributes?[kDocumentSnapAttrChangeSummary],
    ),
    createdAt: createdAt,
  );
}

SetModelRequest setModelRequestForCreateDocument({
  String? title,
  DocumentKind kind = DocumentKind.document,
}) {
  const document = '';
  final documentTitle = _documentTitleOrFallback(title);
  return SetModelRequest(
    modelType: kind.modelTypeName,
    name: documentTitle,
    description: _excerptFrom(document),
    attributes: [
      SetModelAttribute(key: kDocumentAttrDocument, value: document),
      SetModelAttribute(
        key: kDocumentAttrJsonDocument,
        value: _blankDocumentJson(document),
      ),
      SetModelAttribute(key: kDocumentAttrPinned, value: false),
      SetModelAttribute(
        key: kDocumentAttrPublish,
        value: DocumentPublishState.disabled()
            .withCurrentContent(_blankDocumentJson(document))
            .toJson(),
      ),
    ],
    tags: [
      SetModelTag(system: kDocumentStatusTagSystem, nodes: const ['Draft']),
    ],
  );
}

NxDocument documentForCreatedId(
  int id, {
  DateTime? now,
  String? title,
  DocumentKind kind = DocumentKind.document,
}) {
  const document = '';
  final updatedAt = now ?? DateTime.now();
  return NxDocument(
    id: id,
    title: _documentTitleOrFallback(title),
    modelTypeName: kind.modelTypeName,
    document: document,
    jsonDocument: _blankDocumentJson(document),
    wordCount: _countWords(document),
    status: 'Draft',
    topics: const <String>[],
    areaTags: const <String>[],
    tagsBySystem: const <String, List<String>>{
      kDocumentStatusTagSystem: <String>['Draft'],
      kDocumentTopicTagSystem: <String>[],
    },
    pinned: false,
    updatedAt: updatedAt,
    updatedLabel: _relativeLabel(updatedAt),
    versionNumber: 0,
    excerpt: _excerptFrom(document),
    links: const <LinkedModel>[],
    publish: DocumentPublishState.disabled().withCurrentContent(
      _blankDocumentJson(document),
    ),
    readingState: kind == DocumentKind.book ? 'to_read' : '',
  );
}

String _documentTitleOrFallback(String? title) {
  final trimmed = title?.trim();
  return trimmed == null || trimmed.isEmpty ? 'Untitled document' : trimmed;
}

SetModelRequest setModelRequestForUpdateDocument(
  NxDocument document, {
  Set<String> availableTagSystems = const <String>{},
}) {
  final publish = document.publish.withCurrentContent(
    document.jsonDocument,
    tagsBySystem: document.publishTagsBySystem,
  );
  return SetModelRequest(
    id: document.id,
    name: document.title,
    description: document.excerpt,
    attributes: [
      SetModelAttribute(key: kDocumentAttrDocument, value: document.document),
      SetModelAttribute(
        key: kDocumentAttrJsonDocument,
        value: document.jsonDocument,
      ),
      SetModelAttribute(key: kDocumentAttrPinned, value: document.pinned),
      SetModelAttribute(key: kDocumentAttrPublish, value: publish.toJson()),
    ],
    tags: _setModelTagsForDocument(document, availableTagSystems),
  );
}

List<SetModelTag>? _setModelTagsForDocument(
  NxDocument document,
  Set<String> availableTagSystems,
) {
  bool canWrite(String system) {
    return availableTagSystems.isEmpty || availableTagSystems.contains(system);
  }

  final tags = <SetModelTag>[
    if (canWrite(kDocumentStatusTagSystem))
      SetModelTag(system: kDocumentStatusTagSystem, nodes: [document.status]),
    for (final entry in _editableTagSystemsForDocument(document).entries)
      if (canWrite(entry.key))
        SetModelTag(system: entry.key, nodes: entry.value, clear: true),
  ];
  return tags.isEmpty ? null : tags;
}

Map<String, List<String>> _editableTagSystemsForDocument(NxDocument document) {
  final tags = <String, List<String>>{
    for (final entry in document.tagsBySystem.entries)
      if (entry.key != kDocumentStatusTagSystem) entry.key: entry.value,
  };
  tags[kDocumentTopicTagSystem] = document.topics;
  if (document.areaTags.isNotEmpty ||
      tags.containsKey(kDocumentAreaTagSystem)) {
    tags[kDocumentAreaTagSystem] = document.areaTags;
  }
  return tags;
}

SetModelRequest setModelRequestForCreateSnapshot({
  required NxDocument document,
  required int versionNumber,
  required String source,
  required String name,
  required Object? changeSummary,
}) {
  return SetModelRequest(
    modelType: kDocumentSnapModelTypeName,
    name: name,
    attributes: [
      SetModelAttribute(key: kDocumentAttrDocument, value: document.document),
      SetModelAttribute(
        key: kDocumentAttrJsonDocument,
        value: document.jsonDocument,
      ),
      SetModelAttribute(
        key: kDocumentSnapAttrVersionNumber,
        value: versionNumber,
      ),
      SetModelAttribute(key: kDocumentSnapAttrSource, value: source),
      if (changeSummary != null)
        SetModelAttribute(
          key: kDocumentSnapAttrChangeSummary,
          value: changeSummary,
        ),
    ],
  );
}

Map<String, dynamic> documentFetchStruct(ModelType schema) {
  return {
    ...buildKgqlStructFromSchema(
      schema,
      extraTopLevel: const [
        'id',
        'name',
        'description',
        'created_at',
        'updated_at',
        'model_type_id',
      ],
    ),
    kDocumentAttrDocument: true,
    kDocumentAttrJsonDocument: true,
    kDocumentAttrPinned: true,
    kDocumentAttrPublish: true,
    'tags': true,
    'relations': {
      'relation_id': true,
      'model_id': true,
      'model_type': true,
      'name': true,
      'description': true,
    },
    'model_type': {'id': true, 'name': true},
    'DocumentSnap': {
      'id': true,
      'name': true,
      'created_at': true,
      kDocumentAttrDocument: true,
      kDocumentAttrJsonDocument: true,
      kDocumentSnapAttrVersionNumber: true,
      kDocumentSnapAttrSource: true,
      kDocumentSnapAttrChangeSummary: true,
    },
  };
}

Map<String, dynamic> documentSummaryFetchStruct() {
  return {
    'id': true,
    'name': true,
    'description': true,
    'created_at': true,
    'updated_at': true,
    kDocumentAttrPinned: true,
    kDocumentAttrPublish: true,
    kDocumentAttrWordCount: true,
    kBookAttrReadingState: true,
    kBookAttrRank: true,
    'tags': true,
    'model_type': {'id': true, 'name': true},
  };
}

Map<String, dynamic> documentSnapFetchStruct(ModelType schema) {
  return {
    ...buildKgqlStructFromSchema(
      schema,
      extraTopLevel: const [
        'id',
        'name',
        'description',
        'created_at',
        'updated_at',
        'model_type_id',
      ],
    ),
    kDocumentAttrDocument: true,
    kDocumentAttrJsonDocument: true,
    kDocumentSnapAttrVersionNumber: true,
    kDocumentSnapAttrSource: true,
    kDocumentSnapAttrChangeSummary: true,
  };
}

List<DocumentSnap> documentSnapsFromDocumentModel(Model model) {
  final nested =
      model.relations?[kDocumentSnapModelTypeName] ?? const <Model>[];
  final byId = <int, DocumentSnap>{};
  for (final snap in nested) {
    byId[snap.id] = documentSnapFromModel(snap, documentId: model.id);
  }
  final snaps = byId.values.toList()
    ..sort((a, b) {
      final version = b.versionNumber.compareTo(a.versionNumber);
      if (version != 0) return version;
      return b.createdAt.compareTo(a.createdAt);
    });
  return snaps;
}

Map<String, dynamic> _blankDocumentJson(String text) {
  return <String, dynamic>{
    'format': 'appflowy_document',
    'document': <String, dynamic>{
      'type': 'page',
      'children': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'paragraph',
          'data': <String, dynamic>{
            'delta': <Map<String, dynamic>>[
              <String, dynamic>{'insert': text},
            ],
          },
        },
      ],
    },
  };
}

Map<String, dynamic> _jsonMap(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String && raw.trim().isNotEmpty) {
    final decoded = json.decode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return const <String, dynamic>{};
}

String _changeSummaryLabel(Object? raw) {
  if (raw == null) return '';
  if (raw is String) return raw;
  if (raw is Map) {
    final message = raw['message'] ?? raw['summary'] ?? raw['diff'];
    if (message != null) return message.toString();
  }
  return raw.toString();
}

int _countWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return RegExp(r'\S+').allMatches(trimmed).length;
}

String _excerptFrom(String text) {
  final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= 140) return normalized;
  return '${normalized.substring(0, 137)}...';
}

String _relativeLabel(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  return '${diff.inDays}d ago';
}

List<LinkedModel> _linksFromModel(Model model) {
  final relations = model.relationsList;
  if (relations == null || relations.isEmpty) return const <LinkedModel>[];
  return [
    for (final rel in relations)
      if (rel.modelType != kDocumentSnapModelTypeName)
        LinkedModel(
          id: rel.modelId,
          name: rel.name ?? '${rel.modelType} ${rel.modelId}',
          modelType: rel.modelType,
          relationId: rel.relationId,
        ),
  ];
}

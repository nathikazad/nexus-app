import 'dart:convert';

import 'package:nx_db/kgql.dart';
import 'package:nx_notes/data/essay/essay_attr_keys.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';

Essay essayFromModel(Model model, {int versionNumber = 0}) {
  final document = model.attrString(kEssayAttrDocument) ?? '';
  final jsonDocument = _jsonMap(model.attributes?[kEssayAttrJsonDocument]);
  final updatedAt =
      DateTime.tryParse(model.updatedAt ?? '') ??
      DateTime.tryParse(model.createdAt ?? '') ??
      DateTime.now();
  final tags = model.tags ?? const <String, List<String>>{};
  final topics = List<String>.from(tags[kEssayTopicTagSystem] ?? const []);
  final areaTags = List<String>.from(tags[kEssayAreaTagSystem] ?? const []);
  final statusTags = tags[kEssayStatusTagSystem] ?? const [];
  return Essay(
    id: model.id,
    title: model.name,
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
    pinned: model.attrBool(kEssayAttrPinned) ?? false,
    updatedAt: updatedAt,
    updatedLabel: _relativeLabel(updatedAt),
    versionNumber: versionNumber,
    excerpt: _excerptFrom(document),
    links: _linksFromModel(model),
  );
}

Essay essaySummaryFromModel(Model model) {
  final updatedAt =
      DateTime.tryParse(model.updatedAt ?? '') ??
      DateTime.tryParse(model.createdAt ?? '') ??
      DateTime.now();
  final tags = model.tags ?? const <String, List<String>>{};
  final topics = List<String>.from(tags[kEssayTopicTagSystem] ?? const []);
  final areaTags = List<String>.from(tags[kEssayAreaTagSystem] ?? const []);
  final statusTags = tags[kEssayStatusTagSystem] ?? const [];
  final excerpt = model.description?.trim() ?? '';
  return Essay(
    id: model.id,
    title: model.name,
    document: '',
    jsonDocument: const <String, dynamic>{},
    wordCount: model.attrInt(kEssayAttrWordCount) ?? 0,
    status: statusTags.isEmpty ? 'Draft' : statusTags.first,
    topics: topics,
    areaTags: areaTags,
    tagsBySystem: {
      for (final entry in tags.entries)
        entry.key: List<String>.from(entry.value),
    },
    pinned: model.attrBool(kEssayAttrPinned) ?? false,
    updatedAt: updatedAt,
    updatedLabel: _relativeLabel(updatedAt),
    versionNumber: 0,
    excerpt: excerpt,
    links: const <LinkedModel>[],
  );
}

EssaySnap essaySnapFromModel(Model model, {required int essayId}) {
  final document = model.attrString(kEssayAttrDocument) ?? '';
  final createdAt = DateTime.tryParse(model.createdAt ?? '') ?? DateTime.now();
  return EssaySnap(
    id: model.id,
    essayId: essayId,
    name: model.name,
    versionNumber: model.attrInt(kEssaySnapAttrVersionNumber) ?? 0,
    document: document,
    jsonDocument: _jsonMap(model.attributes?[kEssayAttrJsonDocument]),
    source: model.attrString(kEssaySnapAttrSource) ?? '',
    changeSummary: _changeSummaryLabel(
      model.attributes?[kEssaySnapAttrChangeSummary],
    ),
    createdAt: createdAt,
  );
}

SetModelRequest setModelRequestForCreateEssay({String? title}) {
  const document = 'Start writing here.';
  final essayTitle = _essayTitleOrFallback(title);
  return SetModelRequest(
    modelType: kEssayModelTypeName,
    name: essayTitle,
    description: _excerptFrom(document),
    attributes: [
      SetModelAttribute(key: kEssayAttrDocument, value: document),
      SetModelAttribute(
        key: kEssayAttrJsonDocument,
        value: _blankDocumentJson(document),
      ),
      SetModelAttribute(key: kEssayAttrPinned, value: false),
      SetModelAttribute(key: kEssayAttrShareToWeb, value: false),
    ],
    tags: [
      SetModelTag(system: kEssayStatusTagSystem, nodes: const ['Draft']),
    ],
  );
}

Essay essayForCreatedId(int id, {DateTime? now, String? title}) {
  const document = 'Start writing here.';
  final updatedAt = now ?? DateTime.now();
  return Essay(
    id: id,
    title: _essayTitleOrFallback(title),
    document: document,
    jsonDocument: _blankDocumentJson(document),
    wordCount: _countWords(document),
    status: 'Draft',
    topics: const <String>[],
    areaTags: const <String>[],
    tagsBySystem: const <String, List<String>>{
      kEssayStatusTagSystem: <String>['Draft'],
      kEssayTopicTagSystem: <String>[],
    },
    pinned: false,
    updatedAt: updatedAt,
    updatedLabel: _relativeLabel(updatedAt),
    versionNumber: 0,
    excerpt: _excerptFrom(document),
    links: const <LinkedModel>[],
  );
}

String _essayTitleOrFallback(String? title) {
  final trimmed = title?.trim();
  return trimmed == null || trimmed.isEmpty ? 'Untitled essay' : trimmed;
}

SetModelRequest setModelRequestForUpdateEssay(
  Essay essay, {
  Set<String> availableTagSystems = const <String>{},
}) {
  return SetModelRequest(
    id: essay.id,
    name: essay.title,
    description: essay.excerpt,
    attributes: [
      SetModelAttribute(key: kEssayAttrDocument, value: essay.document),
      SetModelAttribute(key: kEssayAttrJsonDocument, value: essay.jsonDocument),
      SetModelAttribute(key: kEssayAttrPinned, value: essay.pinned),
    ],
    tags: _setModelTagsForEssay(essay, availableTagSystems),
  );
}

List<SetModelTag>? _setModelTagsForEssay(
  Essay essay,
  Set<String> availableTagSystems,
) {
  bool canWrite(String system) {
    return availableTagSystems.isEmpty || availableTagSystems.contains(system);
  }

  final tags = <SetModelTag>[
    if (canWrite(kEssayStatusTagSystem))
      SetModelTag(system: kEssayStatusTagSystem, nodes: [essay.status]),
    for (final entry in _editableTagSystemsForEssay(essay).entries)
      if (canWrite(entry.key))
        SetModelTag(system: entry.key, nodes: entry.value, clear: true),
  ];
  return tags.isEmpty ? null : tags;
}

Map<String, List<String>> _editableTagSystemsForEssay(Essay essay) {
  final tags = <String, List<String>>{
    for (final entry in essay.tagsBySystem.entries)
      if (entry.key != kEssayStatusTagSystem) entry.key: entry.value,
  };
  tags[kEssayTopicTagSystem] = essay.topics;
  if (essay.areaTags.isNotEmpty || tags.containsKey(kEssayAreaTagSystem)) {
    tags[kEssayAreaTagSystem] = essay.areaTags;
  }
  return tags;
}

SetModelRequest setModelRequestForCreateSnapshot({
  required Essay essay,
  required int versionNumber,
  required String source,
  required String name,
  required Object? changeSummary,
}) {
  return SetModelRequest(
    modelType: kEssaySnapModelTypeName,
    name: name,
    attributes: [
      SetModelAttribute(key: kEssayAttrDocument, value: essay.document),
      SetModelAttribute(key: kEssayAttrJsonDocument, value: essay.jsonDocument),
      SetModelAttribute(key: kEssaySnapAttrVersionNumber, value: versionNumber),
      SetModelAttribute(key: kEssaySnapAttrSource, value: source),
      if (changeSummary != null)
        SetModelAttribute(
          key: kEssaySnapAttrChangeSummary,
          value: changeSummary,
        ),
    ],
  );
}

Map<String, dynamic> essayFetchStruct(ModelType schema) {
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
    kEssayAttrDocument: true,
    kEssayAttrJsonDocument: true,
    kEssayAttrPinned: true,
    'tags': true,
    'relations': {
      'relation_id': true,
      'model_id': true,
      'model_type': true,
      'name': true,
      'description': true,
    },
    'EssaySnap': {
      'id': true,
      'name': true,
      'created_at': true,
      kEssayAttrDocument: true,
      kEssayAttrJsonDocument: true,
      kEssaySnapAttrVersionNumber: true,
      kEssaySnapAttrSource: true,
      kEssaySnapAttrChangeSummary: true,
    },
  };
}

Map<String, dynamic> essaySummaryFetchStruct() {
  return {
    'id': true,
    'name': true,
    'description': true,
    'created_at': true,
    'updated_at': true,
    kEssayAttrPinned: true,
    kEssayAttrWordCount: true,
    'tags': true,
  };
}

Map<String, dynamic> essaySnapFetchStruct(ModelType schema) {
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
    kEssayAttrDocument: true,
    kEssayAttrJsonDocument: true,
    kEssaySnapAttrVersionNumber: true,
    kEssaySnapAttrSource: true,
    kEssaySnapAttrChangeSummary: true,
  };
}

List<EssaySnap> essaySnapsFromEssayModel(Model model) {
  final nested = model.relations?[kEssaySnapModelTypeName] ?? const <Model>[];
  final byId = <int, EssaySnap>{};
  for (final snap in nested) {
    byId[snap.id] = essaySnapFromModel(snap, essayId: model.id);
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
      if (rel.modelType != kEssaySnapModelTypeName)
        LinkedModel(
          id: rel.modelId,
          name: rel.name ?? '${rel.modelType} ${rel.modelId}',
          modelType: rel.modelType,
          relationId: rel.relationId,
        ),
  ];
}

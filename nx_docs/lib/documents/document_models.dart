import 'dart:convert';

import 'package:crypto/crypto.dart';

class LinkedModel {
  const LinkedModel({
    required this.id,
    required this.name,
    required this.modelType,
    this.relationId,
  });

  final int id;
  final String name;
  final String modelType;
  final int? relationId;
}

enum LinkableModelType {
  project('project', 'Project'),
  person('person', 'Person'),
  company('company', 'Company'),
  document('document', 'Document');

  const LinkableModelType(this.command, this.kgqlName);

  final String command;
  final String kgqlName;

  static LinkableModelType? fromCommand(String command) {
    final normalized = command.trim().toLowerCase();
    for (final type in values) {
      if (type.command == normalized) {
        return type;
      }
    }
    return null;
  }
}

class DocumentAudioBlockTiming {
  const DocumentAudioBlockTiming({
    required this.blockIndex,
    required this.blockKey,
    required this.start,
    required this.end,
  });

  final int blockIndex;
  final String blockKey;
  final Duration start;
  final Duration end;

  Map<String, Object> toJson() => <String, Object>{
    'block_index': blockIndex,
    'block_key': blockKey,
    'start_ms': start.inMilliseconds,
    'end_ms': end.inMilliseconds,
  };

  static DocumentAudioBlockTiming? tryParse(Object? value) {
    if (value is! Map) return null;
    final blockIndex = _asInt(value['block_index']);
    final blockKey = value['block_key'];
    final startMs = _asInt(value['start_ms']);
    final endMs = _asInt(value['end_ms']);
    if (blockIndex == null ||
        blockKey is! String ||
        blockKey.isEmpty ||
        startMs == null ||
        endMs == null ||
        endMs < startMs) {
      return null;
    }
    return DocumentAudioBlockTiming(
      blockIndex: blockIndex,
      blockKey: blockKey,
      start: Duration(milliseconds: startMs),
      end: Duration(milliseconds: endMs),
    );
  }
}

class DocumentAudioManifest {
  const DocumentAudioManifest({required this.duration, required this.blocks});

  final Duration duration;
  final List<DocumentAudioBlockTiming> blocks;

  Map<String, Object> toJson() => <String, Object>{
    'duration_ms': duration.inMilliseconds,
    'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
  };

  static DocumentAudioManifest? tryParse(Object? value) {
    if (value is! Map) return null;
    final durationMs = _asInt(value['duration_ms']);
    final rawBlocks = value['blocks'];
    if (durationMs == null || rawBlocks is! List) return null;
    final blocks = rawBlocks
        .map(DocumentAudioBlockTiming.tryParse)
        .whereType<DocumentAudioBlockTiming>()
        .toList(growable: false);
    if (blocks.isEmpty) return null;
    return DocumentAudioManifest(
      duration: Duration(milliseconds: durationMs),
      blocks: blocks,
    );
  }

  DocumentAudioBlockTiming? blockAt(Duration position) {
    for (final block in blocks) {
      if (position >= block.start && position < block.end) return block;
    }
    return position >= duration ? blocks.last : null;
  }

  DocumentAudioBlockTiming? blockForKey(String? key) {
    if (key == null) return null;
    for (final block in blocks) {
      if (block.blockKey == key) return block;
    }
    return null;
  }
}

class DocumentAudio {
  const DocumentAudio({
    required this.url,
    required this.sourceHash,
    required this.manifest,
  });

  final String url;
  final String sourceHash;
  final DocumentAudioManifest manifest;
}

int? _asInt(Object? value) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };
}

class DocumentKey {
  const DocumentKey({required this.localId, this.remoteId});

  final String localId;
  final int? remoteId;

  DocumentKey withRemoteId(int value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'value', 'must be positive');
    }
    return DocumentKey(localId: localId, remoteId: value);
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentKey && other.localId == localId;
  }

  @override
  int get hashCode => localId.hashCode;

  @override
  String toString() => 'DocumentKey(localId: $localId, remoteId: $remoteId)';
}

const kDefaultDocumentPublishStatus = 'draft';
const kPublicDocumentTopicTagSystem = 'Topic';

class DocumentPublishState {
  const DocumentPublishState({
    required this.enabled,
    required this.dirty,
    this.contentHash,
    this.lastPublishedHash,
    this.firstPublishedAt,
    this.lastPublishedAt,
    this.status = kDefaultDocumentPublishStatus,
    this.lastError,
    this.slug,
    this.title,
  });

  factory DocumentPublishState.disabled() {
    return const DocumentPublishState(enabled: false, dirty: false);
  }

  factory DocumentPublishState.fromJson(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      final decoded = json.decode(raw);
      return DocumentPublishState.fromJson(decoded);
    }
    if (raw is! Map) {
      return DocumentPublishState.disabled();
    }
    final jsonMap = Map<String, dynamic>.from(raw);
    return DocumentPublishState(
      enabled: jsonMap['enabled'] == true,
      dirty: jsonMap['dirty'] == true,
      contentHash: _stringOrNull(jsonMap['content_hash']),
      lastPublishedHash: _stringOrNull(jsonMap['last_published_hash']),
      firstPublishedAt: _stringOrNull(jsonMap['first_published_at']),
      lastPublishedAt: _stringOrNull(jsonMap['last_published_at']),
      status: _stringOrNull(jsonMap['status']) ?? kDefaultDocumentPublishStatus,
      lastError: _stringOrNull(jsonMap['last_error']),
      slug: _stringOrNull(jsonMap['slug']),
      title: _stringOrNull(jsonMap['title']),
    );
  }

  final bool enabled;
  final bool dirty;
  final String? contentHash;
  final String? lastPublishedHash;
  final String? firstPublishedAt;
  final String? lastPublishedAt;
  final String status;
  final String? lastError;
  final String? slug;
  final String? title;

  bool get published => enabled && !dirty && contentHash == lastPublishedHash;

  DocumentPublishState copyWith({
    bool? enabled,
    bool? dirty,
    String? contentHash,
    String? lastPublishedHash,
    String? firstPublishedAt,
    String? lastPublishedAt,
    String? status,
    String? lastError,
    String? slug,
    String? title,
    bool clearContentHash = false,
    bool clearLastPublishedHash = false,
    bool clearFirstPublishedAt = false,
    bool clearLastPublishedAt = false,
    bool clearLastError = false,
    bool clearSlug = false,
    bool clearTitle = false,
  }) {
    return DocumentPublishState(
      enabled: enabled ?? this.enabled,
      dirty: dirty ?? this.dirty,
      contentHash: clearContentHash ? null : contentHash ?? this.contentHash,
      lastPublishedHash: clearLastPublishedHash
          ? null
          : lastPublishedHash ?? this.lastPublishedHash,
      firstPublishedAt: clearFirstPublishedAt
          ? null
          : firstPublishedAt ?? this.firstPublishedAt,
      lastPublishedAt: clearLastPublishedAt
          ? null
          : lastPublishedAt ?? this.lastPublishedAt,
      status: status ?? this.status,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      slug: clearSlug ? null : slug ?? this.slug,
      title: clearTitle ? null : title ?? this.title,
    );
  }

  DocumentPublishState withCurrentContent(
    Map<String, dynamic> jsonDocument, {
    Map<String, List<String>> tagsBySystem = const <String, List<String>>{},
  }) {
    final hash = appFlowyContentHash(jsonDocument, tagsBySystem: tagsBySystem);
    if (!enabled) {
      return copyWith(
        contentHash: hash,
        dirty: dirty,
        status: dirty ? 'pending' : kDefaultDocumentPublishStatus,
      );
    }
    return copyWith(
      contentHash: hash,
      dirty: hash != lastPublishedHash,
      status: hash == lastPublishedHash ? 'published' : 'pending',
      clearLastError: true,
    );
  }

  DocumentPublishState enable({
    required Map<String, dynamic> jsonDocument,
    required String publishedAt,
    Map<String, List<String>> tagsBySystem = const <String, List<String>>{},
    String? title,
    String? slug,
  }) {
    final hash = appFlowyContentHash(jsonDocument, tagsBySystem: tagsBySystem);
    return copyWith(
      enabled: true,
      dirty: true,
      contentHash: hash,
      firstPublishedAt: firstPublishedAt ?? publishedAt,
      status: 'pending',
      title: title,
      slug: slug,
      clearLastError: true,
    );
  }

  DocumentPublishState disable() {
    return copyWith(enabled: false, dirty: true, status: 'pending');
  }

  DocumentPublishState markActivated({
    required String activatedHash,
    required String publishedAt,
  }) {
    return copyWith(
      dirty: false,
      contentHash: activatedHash,
      lastPublishedHash: activatedHash,
      lastPublishedAt: publishedAt,
      status: 'published',
      clearLastError: true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'dirty': dirty,
      'content_hash': contentHash,
      'last_published_hash': lastPublishedHash,
      'first_published_at': firstPublishedAt,
      'last_published_at': lastPublishedAt,
      'status': status,
      'last_error': lastError,
      'slug': slug,
      'title': title,
    };
  }
}

String appFlowyContentHash(
  Map<String, dynamic> jsonDocument, {
  Map<String, List<String>> tagsBySystem = const <String, List<String>>{},
}) {
  final contentEnvelope = <String, dynamic>{
    'format': jsonDocument['format'],
    'document': jsonDocument['document'],
    'tags': publicDocumentTags(tagsBySystem),
  };
  final canonicalJson = json.encode(_canonicalize(contentEnvelope));
  return 'sha256:${sha256.convert(utf8.encode(canonicalJson))}';
}

Map<String, List<String>> publicDocumentTags(
  Map<String, List<String>> tagsBySystem,
) {
  final topicTags = tagsBySystem[kPublicDocumentTopicTagSystem];
  if (topicTags == null) return const <String, List<String>>{};
  final normalized =
      topicTags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  if (normalized.isEmpty) return const <String, List<String>>{};
  return <String, List<String>>{kPublicDocumentTopicTagSystem: normalized};
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList();
  }
  return value;
}

String? _stringOrNull(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

class DocumentTagFilter {
  const DocumentTagFilter({
    required this.system,
    required this.node,
    this.includeDescendants = false,
  });

  final String system;
  final String node;
  final bool includeDescendants;
}

class DocumentQuery {
  const DocumentQuery({
    this.searchText = '',
    this.tagFilters = const <DocumentTagFilter>[],
    this.pinnedOnly = false,
  });

  final String searchText;
  final List<DocumentTagFilter> tagFilters;
  final bool pinnedOnly;
}

class DocumentResultContext {
  const DocumentResultContext({
    required this.title,
    required this.query,
    required this.resultIds,
    this.results = const <NxDocument>[],
  });

  final String title;
  final DocumentQuery query;
  final List<int> resultIds;
  final List<NxDocument> results;
}

class DocumentSnap {
  const DocumentSnap({
    required this.id,
    required this.documentId,
    required this.name,
    required this.versionNumber,
    required this.document,
    required this.jsonDocument,
    required this.source,
    required this.changeSummary,
    required this.createdAt,
  });

  final int id;
  final int documentId;
  final String name;
  final int versionNumber;
  final String document;
  final Map<String, dynamic> jsonDocument;
  final String source;
  final String changeSummary;
  final DateTime createdAt;
}

final class DocumentSummary {
  const DocumentSummary({
    required this.id,
    required this.title,
    required this.modelTypeName,
    required this.wordCount,
    required this.status,
    required this.topics,
    required this.areaTags,
    required this.tagsBySystem,
    required this.pinned,
    required this.updatedAt,
    required this.updatedLabel,
    required this.excerpt,
    required this.publish,
    required this.readingState,
    this.bookRank,
  });

  factory DocumentSummary.fromDocument(NxDocument document) {
    return DocumentSummary(
      id: document.id,
      title: document.title,
      modelTypeName: document.modelTypeName,
      wordCount: document.wordCount,
      status: document.status,
      topics: document.topics,
      areaTags: document.areaTags,
      tagsBySystem: document.tagsBySystem,
      pinned: document.pinned,
      updatedAt: document.updatedAt,
      updatedLabel: document.updatedLabel,
      excerpt: document.excerpt,
      publish: document.publish,
      readingState: document.readingState,
      bookRank: document.bookRank,
    );
  }

  final int id;
  final String title;
  final String modelTypeName;
  final int wordCount;
  final String status;
  final List<String> topics;
  final List<String> areaTags;
  final Map<String, List<String>> tagsBySystem;
  final bool pinned;
  final DateTime updatedAt;
  final String updatedLabel;
  final String excerpt;
  final DocumentPublishState publish;
  final String readingState;
  final int? bookRank;

  bool get isBook => modelTypeName == 'Book';

  /// Converts a catalog row into the existing presentation model without
  /// inventing a document body. Opening the row must still go through a
  /// [DocumentSession] to load complete content.
  NxDocument toDocument() {
    return NxDocument(
      id: id,
      title: title,
      modelTypeName: modelTypeName,
      document: '',
      jsonDocument: const <String, dynamic>{},
      wordCount: wordCount,
      status: status,
      topics: topics,
      areaTags: areaTags,
      tagsBySystem: tagsBySystem,
      pinned: pinned,
      updatedAt: updatedAt,
      updatedLabel: updatedLabel,
      versionNumber: 0,
      excerpt: excerpt,
      links: const <LinkedModel>[],
      publish: publish,
      readingState: readingState,
      bookRank: bookRank,
    );
  }
}

enum DocumentKind {
  document('Document', 'Document'),
  book('Book', 'Book');

  const DocumentKind(this.modelTypeName, this.label);

  final String modelTypeName;
  final String label;
}

class NxDocument {
  const NxDocument({
    required this.id,
    required this.title,
    required this.modelTypeName,
    required this.document,
    required this.jsonDocument,
    required this.wordCount,
    required this.status,
    required this.topics,
    required this.areaTags,
    required this.tagsBySystem,
    required this.pinned,
    required this.updatedAt,
    required this.updatedLabel,
    required this.versionNumber,
    required this.excerpt,
    required this.links,
    this.publish = const DocumentPublishState(enabled: false, dirty: false),
    this.readingState = '',
    this.bookRank,
    this.audio,
  });

  final int id;
  final String title;
  final String modelTypeName;
  final String document;
  final Map<String, dynamic> jsonDocument;
  final int wordCount;
  final String status;
  final List<String> topics;
  final List<String> areaTags;
  final Map<String, List<String>> tagsBySystem;
  final bool pinned;
  final DateTime updatedAt;
  final String updatedLabel;
  final int versionNumber;
  final String excerpt;
  final List<LinkedModel> links;
  final DocumentPublishState publish;
  final String readingState;
  final int? bookRank;
  final DocumentAudio? audio;

  bool get hasFullDocument =>
      document.isNotEmpty ||
      jsonDocument.containsKey('format') ||
      jsonDocument.containsKey('document');

  bool get isBook => modelTypeName == 'Book';

  Map<String, List<String>> get publishTagsBySystem {
    return <String, List<String>>{
      ...tagsBySystem,
      kPublicDocumentTopicTagSystem: topics,
    };
  }

  NxDocument copyWith({
    String? title,
    String? modelTypeName,
    String? document,
    Map<String, dynamic>? jsonDocument,
    int? wordCount,
    String? status,
    List<String>? topics,
    List<String>? areaTags,
    Map<String, List<String>>? tagsBySystem,
    bool? pinned,
    DateTime? updatedAt,
    String? updatedLabel,
    int? versionNumber,
    String? excerpt,
    List<LinkedModel>? links,
    DocumentPublishState? publish,
    String? readingState,
    int? bookRank,
    bool clearBookRank = false,
    DocumentAudio? audio,
    bool clearAudio = false,
  }) {
    return NxDocument(
      id: id,
      title: title ?? this.title,
      modelTypeName: modelTypeName ?? this.modelTypeName,
      document: document ?? this.document,
      jsonDocument: jsonDocument ?? this.jsonDocument,
      wordCount: wordCount ?? this.wordCount,
      status: status ?? this.status,
      topics: topics ?? this.topics,
      areaTags: areaTags ?? this.areaTags,
      tagsBySystem: tagsBySystem ?? this.tagsBySystem,
      pinned: pinned ?? this.pinned,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedLabel: updatedLabel ?? this.updatedLabel,
      versionNumber: versionNumber ?? this.versionNumber,
      excerpt: excerpt ?? this.excerpt,
      links: links ?? this.links,
      publish: publish ?? this.publish,
      readingState: readingState ?? this.readingState,
      bookRank: clearBookRank ? null : bookRank ?? this.bookRank,
      audio: clearAudio ? null : audio ?? this.audio,
    );
  }
}

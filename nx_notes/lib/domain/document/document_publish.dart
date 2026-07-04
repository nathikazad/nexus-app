import 'dart:convert';

import 'package:crypto/crypto.dart';

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
  final normalized = topicTags
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

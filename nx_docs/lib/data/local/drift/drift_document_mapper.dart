import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:nx_docs/data/local/drift/notes_database.dart';
import 'package:nx_docs/domain/document/document.dart';
import 'package:nx_docs/domain/document/document_audio.dart';
import 'package:nx_docs/domain/document/document_identity.dart';
import 'package:nx_docs/domain/document/document_publish.dart';
import 'package:nx_docs/domain/links/linked_model.dart';
import 'package:nx_docs/domain/sync/document_revision.dart';
import 'package:nx_docs/domain/sync/local_document.dart';
import 'package:nx_docs/domain/sync/pending_operation.dart';
import 'package:nx_docs/domain/sync/sync_state.dart';

class DriftDocumentMapper {
  const DriftDocumentMapper();

  LocalDocumentsCompanion toDocumentCompanion(LocalDocument local) {
    return LocalDocumentsCompanion(
      localId: Value<String>(local.key.localId),
      remoteId: Value<int?>(local.key.remoteId),
      accountKey: Value<String>(local.accountKey),
      documentJson: Value<String>(jsonEncode(_documentToJson(local.document))),
      localUpdatedAt: Value<DateTime>(local.localUpdatedAt),
      serverRevision: Value<String?>(local.serverRevision?.value),
      baseServerRevision: Value<String?>(local.baseServerRevision?.value),
      serverHash: Value<String?>(local.serverHash),
      syncState: Value<String>(local.syncState.name),
      deletedLocally: Value<bool>(local.deletedLocally),
    );
  }

  LocalDocument fromDocumentRow(LocalDocumentRow row) {
    return LocalDocument(
      key: DocumentKey(localId: row.localId, remoteId: row.remoteId),
      accountKey: row.accountKey,
      document: _documentFromJson(
        Map<String, Object?>.from(jsonDecode(row.documentJson) as Map),
      ),
      localUpdatedAt: row.localUpdatedAt,
      serverRevision: _revision(row.serverRevision),
      baseServerRevision: _revision(row.baseServerRevision),
      serverHash: row.serverHash,
      syncState: DocumentSyncState.values.byName(row.syncState),
      deletedLocally: row.deletedLocally,
    );
  }

  SyncOutboxCompanion toOperationCompanion(PendingOperation operation) {
    return SyncOutboxCompanion(
      operationId: Value<String>(operation.operationId),
      accountKey: Value<String>(operation.accountKey),
      aggregateId: Value<String>(operation.documentKey.localId),
      operationType: Value<String>(operation.type.name),
      payloadJson: Value<String>(jsonEncode(operation.payload)),
      baseRevision: Value<String?>(operation.baseRevision?.value),
      status: Value<String>(operation.status.name),
      attemptCount: Value<int>(operation.attemptCount),
      nextAttemptAt: Value<DateTime?>(operation.nextAttemptAt),
      leaseOwner: Value<String?>(operation.leaseOwner),
      leaseExpiresAt: Value<DateTime?>(operation.leaseExpiresAt),
      lastError: Value<String?>(operation.lastError),
      createdAt: Value<DateTime>(operation.createdAt),
    );
  }

  PendingOperation fromOperationRow(
    SyncOutboxData row, {
    required int? remoteId,
  }) {
    return PendingOperation(
      operationId: row.operationId,
      accountKey: row.accountKey,
      documentKey: DocumentKey(localId: row.aggregateId, remoteId: remoteId),
      type: PendingOperationType.values.byName(row.operationType),
      payload: Map<String, Object?>.from(jsonDecode(row.payloadJson) as Map),
      baseRevision: _revision(row.baseRevision),
      status: PendingOperationStatus.values.byName(row.status),
      attemptCount: row.attemptCount,
      nextAttemptAt: row.nextAttemptAt,
      leaseOwner: row.leaseOwner,
      leaseExpiresAt: row.leaseExpiresAt,
      lastError: row.lastError,
      createdAt: row.createdAt,
    );
  }

  RemoteRevision? _revision(String? value) {
    return value == null ? null : RemoteRevision(value);
  }

  String documentToJsonString(NxDocument document) {
    return jsonEncode(_documentToJson(document));
  }

  NxDocument documentFromJsonString(String value) {
    return _documentFromJson(
      Map<String, Object?>.from(jsonDecode(value) as Map),
    );
  }
}

Map<String, Object?> _documentToJson(NxDocument document) {
  return <String, Object?>{
    'id': document.id,
    'title': document.title,
    'model_type_name': document.modelTypeName,
    'document': document.document,
    'json_document': document.jsonDocument,
    'word_count': document.wordCount,
    'status': document.status,
    'topics': document.topics,
    'area_tags': document.areaTags,
    'tags_by_system': document.tagsBySystem,
    'pinned': document.pinned,
    'updated_at': document.updatedAt.toUtc().toIso8601String(),
    'updated_label': document.updatedLabel,
    'version_number': document.versionNumber,
    'excerpt': document.excerpt,
    'links': <Map<String, Object?>>[
      for (final link in document.links)
        <String, Object?>{
          'id': link.id,
          'name': link.name,
          'model_type': link.modelType,
          'relation_id': link.relationId,
        },
    ],
    'publish': document.publish.toJson(),
    'reading_state': document.readingState,
    'book_rank': document.bookRank,
    if (document.audio case final audio?)
      'audio': <String, Object>{
        'url': audio.url,
        'source_hash': audio.sourceHash,
        'manifest': audio.manifest.toJson(),
      },
  };
}

NxDocument _documentFromJson(Map<String, Object?> json) {
  final tags = Map<String, Object?>.from(json['tags_by_system']! as Map);
  final links = (json['links']! as List).cast<Map>();
  final rawAudio = json['audio'];
  final audioMap = rawAudio is Map ? rawAudio : null;
  final audioManifest = DocumentAudioManifest.tryParse(audioMap?['manifest']);
  return NxDocument(
    id: json['id']! as int,
    title: json['title']! as String,
    modelTypeName: json['model_type_name']! as String,
    document: json['document']! as String,
    jsonDocument: Map<String, dynamic>.from(json['json_document']! as Map),
    wordCount: json['word_count']! as int,
    status: json['status']! as String,
    topics: List<String>.from(json['topics']! as List),
    areaTags: List<String>.from(json['area_tags']! as List),
    tagsBySystem: <String, List<String>>{
      for (final entry in tags.entries)
        entry.key: List<String>.from(entry.value! as List),
    },
    pinned: json['pinned']! as bool,
    updatedAt: DateTime.parse(json['updated_at']! as String),
    updatedLabel: json['updated_label']! as String,
    versionNumber: json['version_number']! as int,
    excerpt: json['excerpt']! as String,
    links: <LinkedModel>[
      for (final raw in links)
        LinkedModel(
          id: raw['id']! as int,
          name: raw['name']! as String,
          modelType: raw['model_type']! as String,
          relationId: raw['relation_id'] as int?,
        ),
    ],
    publish: DocumentPublishState.fromJson(json['publish']),
    readingState: json['reading_state']! as String,
    bookRank: json['book_rank'] as int?,
    audio:
        audioMap?['url'] is String &&
            audioMap?['source_hash'] is String &&
            audioManifest != null
        ? DocumentAudio(
            url: audioMap!['url']! as String,
            sourceHash: audioMap['source_hash']! as String,
            manifest: audioManifest,
          )
        : null,
  );
}

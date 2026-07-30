import 'package:nx_notes/domain/sync/remote_document.dart';

final class DocumentManifestEntry {
  const DocumentManifestEntry({required this.documentId, this.serverHash});

  final int documentId;
  final String? serverHash;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': documentId,
    'hash': serverHash,
  };
}

final class DocumentSyncBundle {
  const DocumentSyncBundle({
    this.documents = const <RemoteDocument>[],
    this.deletedIds = const <int>[],
  });

  final List<RemoteDocument> documents;
  final List<int> deletedIds;
}

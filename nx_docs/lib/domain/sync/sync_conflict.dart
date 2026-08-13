import 'package:nx_docs/domain/document/document.dart';
import 'package:nx_docs/domain/document/document_identity.dart';
import 'package:nx_docs/domain/sync/document_revision.dart';

class SyncConflict {
  const SyncConflict({
    required this.documentKey,
    required this.localDocument,
    required this.remoteDocument,
    required this.remoteRevision,
    required this.detectedAt,
  });

  final DocumentKey documentKey;
  final NxDocument localDocument;
  final NxDocument remoteDocument;
  final RemoteRevision remoteRevision;
  final DateTime detectedAt;
}

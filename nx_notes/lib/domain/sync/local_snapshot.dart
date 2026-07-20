import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';

class LocalSnapshot {
  const LocalSnapshot({
    required this.snapshotId,
    required this.accountKey,
    required this.documentKey,
    required this.document,
    required this.createdAt,
    required this.source,
  });

  final String snapshotId;
  final String accountKey;
  final DocumentKey documentKey;
  final NxDocument document;
  final DateTime createdAt;
  final String source;
}

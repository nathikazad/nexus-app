import 'package:nx_docs/domain/document/document.dart';
import 'package:nx_docs/domain/document/document_identity.dart';
import 'package:nx_docs/domain/sync/document_revision.dart';

class RemoteDocument {
  const RemoteDocument({
    required this.key,
    required this.document,
    required this.revision,
    this.serverHash,
    this.deleted = false,
  });

  final DocumentKey key;
  final NxDocument document;
  final RemoteRevision revision;
  final String? serverHash;
  final bool deleted;
}

class RemoteWriteResult {
  const RemoteWriteResult({
    required this.key,
    required this.revision,
    this.serverHash,
  });

  final DocumentKey key;
  final RemoteRevision revision;
  final String? serverHash;
}

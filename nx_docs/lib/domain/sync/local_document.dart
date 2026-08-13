import 'package:nx_docs/domain/document/document.dart';
import 'package:nx_docs/domain/document/document_identity.dart';
import 'package:nx_docs/domain/sync/document_revision.dart';
import 'package:nx_docs/domain/sync/sync_state.dart';

class LocalDocument {
  const LocalDocument({
    required this.key,
    required this.accountKey,
    required this.document,
    required this.localUpdatedAt,
    required this.syncState,
    this.serverRevision,
    this.baseServerRevision,
    this.serverHash,
    this.deletedLocally = false,
  });

  final DocumentKey key;
  final String accountKey;
  final NxDocument document;
  final DateTime localUpdatedAt;
  final RemoteRevision? serverRevision;
  final RemoteRevision? baseServerRevision;
  final String? serverHash;
  final DocumentSyncState syncState;
  final bool deletedLocally;

  LocalDocument copyWith({
    DocumentKey? key,
    String? accountKey,
    NxDocument? document,
    DateTime? localUpdatedAt,
    RemoteRevision? serverRevision,
    bool clearServerRevision = false,
    RemoteRevision? baseServerRevision,
    bool clearBaseServerRevision = false,
    String? serverHash,
    bool clearServerHash = false,
    DocumentSyncState? syncState,
    bool? deletedLocally,
  }) {
    return LocalDocument(
      key: key ?? this.key,
      accountKey: accountKey ?? this.accountKey,
      document: document ?? this.document,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      serverRevision: clearServerRevision
          ? null
          : serverRevision ?? this.serverRevision,
      baseServerRevision: clearBaseServerRevision
          ? null
          : baseServerRevision ?? this.baseServerRevision,
      serverHash: clearServerHash ? null : serverHash ?? this.serverHash,
      syncState: syncState ?? this.syncState,
      deletedLocally: deletedLocally ?? this.deletedLocally,
    );
  }
}

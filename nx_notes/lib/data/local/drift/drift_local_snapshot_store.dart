import 'package:drift/drift.dart';
import 'package:nx_notes/application/ports/local_snapshot_store.dart';
import 'package:nx_notes/data/local/drift/drift_document_mapper.dart';
import 'package:nx_notes/data/local/drift/notes_database.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/local_snapshot.dart';

class DriftLocalSnapshotStore implements LocalSnapshotStore {
  const DriftLocalSnapshotStore({
    required this.database,
    required this.accountKey,
    this.mapper = const DriftDocumentMapper(),
  });

  final NotesDatabase database;
  @override
  final String accountKey;
  final DriftDocumentMapper mapper;

  @override
  Future<void> save(LocalSnapshot snapshot) async {
    if (snapshot.accountKey != accountKey) {
      throw StateError('snapshot belongs to a different account');
    }
    await database
        .into(database.localSnapshots)
        .insertOnConflictUpdate(
          LocalSnapshotsCompanion(
            snapshotId: Value<String>(snapshot.snapshotId),
            accountKey: Value<String>(snapshot.accountKey),
            localId: Value<String>(snapshot.documentKey.localId),
            remoteId: Value<int?>(snapshot.documentKey.remoteId),
            documentJson: Value<String>(
              mapper.documentToJsonString(snapshot.document),
            ),
            createdAt: Value<DateTime>(snapshot.createdAt),
            source: Value<String>(snapshot.source),
          ),
        );
  }

  @override
  Future<List<LocalSnapshot>> list(DocumentKey documentKey) async {
    final rows =
        await (database.select(database.localSnapshots)
              ..where(
                (table) =>
                    table.accountKey.equals(accountKey) &
                    table.localId.equals(documentKey.localId),
              )
              ..orderBy(<OrderingTerm Function(LocalSnapshots)>[
                (table) => OrderingTerm.desc(table.createdAt),
              ]))
            .get();
    return rows
        .map(
          (row) => LocalSnapshot(
            snapshotId: row.snapshotId,
            accountKey: row.accountKey,
            documentKey: DocumentKey(
              localId: row.localId,
              remoteId: row.remoteId,
            ),
            document: mapper.documentFromJsonString(row.documentJson),
            createdAt: row.createdAt,
            source: row.source,
          ),
        )
        .toList();
  }
}

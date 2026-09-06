import 'package:drift/drift.dart';

part 'notes_database.g.dart';

@DataClassName('LocalDocumentRow')
class LocalDocuments extends Table {
  TextColumn get localId => text()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get accountKey => text()();
  TextColumn get documentJson => text()();
  DateTimeColumn get localUpdatedAt => dateTime()();
  TextColumn get serverRevision => text().nullable()();
  TextColumn get baseServerRevision => text().nullable()();
  TextColumn get serverHash => text().nullable()();
  TextColumn get syncState => text()();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{localId, accountKey};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{accountKey, remoteId},
  ];
}

class SyncOutbox extends Table {
  TextColumn get operationId => text()();
  TextColumn get accountKey => text()();
  TextColumn get aggregateId => text()();
  TextColumn get operationType => text()();
  TextColumn get payloadJson => text()();
  TextColumn get baseRevision => text().nullable()();
  TextColumn get status => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get leaseOwner => text().nullable()();
  DateTimeColumn get leaseExpiresAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{operationId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{accountKey, aggregateId},
  ];
}

class SyncMetadata extends Table {
  TextColumn get accountKey => text()();
  TextColumn get cursor => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{accountKey};
}

@DataClassName('DocumentSummaryRow')
class DocumentSummaries extends Table {
  TextColumn get accountKey => text()();
  IntColumn get remoteId => integer()();
  TextColumn get documentJson => text()();
  DateTimeColumn get remoteUpdatedAt => dateTime()();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{accountKey, remoteId};
}

class CatalogMemberships extends Table {
  TextColumn get accountKey => text()();
  TextColumn get catalogKey => text()();
  IntColumn get remoteId => integer()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    accountKey,
    catalogKey,
    remoteId,
  };
}

@DataClassName('SyncConflictRow')
class SyncConflicts extends Table {
  TextColumn get accountKey => text()();
  TextColumn get localId => text()();
  TextColumn get localDocumentJson => text()();
  TextColumn get remoteDocumentJson => text()();
  TextColumn get remoteRevision => text()();
  DateTimeColumn get detectedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{accountKey, localId};
}

@DataClassName('LocalSnapshotRow')
class LocalSnapshots extends Table {
  TextColumn get snapshotId => text()();
  TextColumn get accountKey => text()();
  TextColumn get localId => text()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get documentJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get source => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{snapshotId};
}

@DriftDatabase(
  tables: <Type>[
    LocalDocuments,
    SyncOutbox,
    SyncMetadata,
    DocumentSummaries,
    CatalogMemberships,
    SyncConflicts,
    LocalSnapshots,
  ],
)
class NotesDatabase extends _$NotesDatabase {
  NotesDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  Future<void> _createProjectionIndexes() => customStatement(
    'CREATE INDEX IF NOT EXISTS document_summary_order ON document_summaries '
    '(account_key, deleted_locally, remote_updated_at DESC, remote_id DESC)',
  );

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createProjectionIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(localSnapshots);
      if (from < 3) await migrator.createTable(catalogMemberships);
      if (from < 4) {
        await migrator.createTable(documentSummaries);
        await customStatement('''
          INSERT OR IGNORE INTO document_summaries (
            account_key,
            remote_id,
            document_json,
            remote_updated_at,
            deleted_locally
          )
          SELECT
            account_key,
            remote_id,
            document_json,
            local_updated_at,
            deleted_locally
          FROM local_documents
          WHERE remote_id IS NOT NULL
          ''');
      }
      if (from < 5) {
        await migrator.addColumn(localDocuments, localDocuments.serverHash);
      }
      if (from < 6) {
        await _createProjectionIndexes();
        await customStatement("""
          UPDATE document_summaries SET document_json = json_set(
            document_json, '\$.document', '', '\$.json_document', json('{}'),
            '\$.excerpt', substr(json_extract(document_json, '\$.excerpt'), 1, 320))
          """);
        // Previous recent/pinned memberships were truncated on write. Rebuild
        // eligibility once; future edits update only their own membership.
        for (final key in [
          'all',
          'recent:20',
          'pinned:20',
          'pinned:50',
          'books:all',
        ]) {
          final predicate = key.startsWith('pinned')
              ? "AND json_extract(document_json, '\$.pinned') = 1"
              : key.startsWith('books')
              ? "AND json_extract(document_json, '\$.model_type_name') = 'Book'"
              : '';
          await customStatement(
            'INSERT OR IGNORE INTO catalog_memberships (account_key, catalog_key, remote_id, position) '
            'SELECT account_key, ?, remote_id, 0 FROM document_summaries WHERE deleted_locally = 0 $predicate',
            [key],
          );
        }
      }
    },
  );
}

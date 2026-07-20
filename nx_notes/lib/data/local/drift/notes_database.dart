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

@DriftDatabase(
  tables: <Type>[LocalDocuments, SyncOutbox, SyncMetadata, SyncConflicts],
)
class NotesDatabase extends _$NotesDatabase {
  NotesDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

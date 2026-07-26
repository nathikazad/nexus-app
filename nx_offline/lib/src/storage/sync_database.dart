import 'package:drift/drift.dart';

part 'sync_database.g.dart';

@DataClassName('LocalEntityRow')
class LocalEntities extends Table {
  TextColumn get accountKey => text()();
  TextColumn get collection => text()();
  TextColumn get localId => text()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get revision => text().nullable()();
  TextColumn get baseRevision => text().nullable()();
  TextColumn get syncState => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {accountKey, collection, localId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {accountKey, collection, remoteId},
  ];
}

class SyncOutbox extends Table {
  TextColumn get operationId => text()();
  TextColumn get accountKey => text()();
  TextColumn get collection => text()();
  TextColumn get localId => text()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get mutationType => text()();
  TextColumn get payloadJson => text()();
  TextColumn get baseRevision => text().nullable()();
  TextColumn get status => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get leaseOwner => text().nullable()();
  DateTimeColumn get leaseExpiresAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get operationGroup => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {accountKey, collection, localId},
  ];
}

@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get accountKey => text()();
  TextColumn get collection => text()();
  TextColumn get cursor => text()();

  @override
  Set<Column<Object>> get primaryKey => {accountKey, collection};
}

@DataClassName('SyncConflictRow')
class SyncConflicts extends Table {
  TextColumn get accountKey => text()();
  TextColumn get collection => text()();
  TextColumn get localId => text()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get localPayloadJson => text()();
  TextColumn get remotePayloadJson => text()();
  TextColumn get remoteRevision => text()();
  DateTimeColumn get detectedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {accountKey, collection, localId};
}

@DriftDatabase(tables: [LocalEntities, SyncOutbox, SyncCursors, SyncConflicts])
class SyncDatabase extends _$SyncDatabase {
  SyncDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

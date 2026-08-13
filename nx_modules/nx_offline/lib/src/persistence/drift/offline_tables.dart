import 'package:drift/drift.dart';

/// Durable operations shared by application-owned Drift databases.
///
/// Applications include this table beside their typed domain tables. The
/// application repository is then able to update its domain projection and
/// enqueue work in one physical SQLite transaction.
class OfflineOutboxEntries extends Table {
  TextColumn get operationId => text()();
  TextColumn get accountKey => text()();
  TextColumn get collection => text()();
  TextColumn get aggregateId => text()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get operationType => text()();
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
  Set<Column<Object>> get primaryKey => <Column<Object>>{operationId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{accountKey, collection, aggregateId},
  ];

  @override
  String get tableName => 'offline_outbox';
}

/// Per-dataset reconciliation metadata owned by the application database.
class OfflineSyncMetadataEntries extends Table {
  TextColumn get accountKey => text()();
  TextColumn get dataset => text()();
  TextColumn get cursor => text().nullable()();
  DateTimeColumn get lastCompletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{accountKey, dataset};

  @override
  String get tableName => 'offline_sync_metadata';
}

/// Opaque conflict payloads. Applications decide how to encode and present
/// their domain values; the shared runtime only guarantees durability.
class OfflineConflictEntries extends Table {
  TextColumn get accountKey => text()();
  TextColumn get collection => text()();
  TextColumn get aggregateId => text()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get localPayloadJson => text()();
  TextColumn get remotePayloadJson => text()();
  TextColumn get remoteRevision => text()();
  DateTimeColumn get detectedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    accountKey,
    collection,
    aggregateId,
  };

  @override
  String get tableName => 'offline_conflicts';
}

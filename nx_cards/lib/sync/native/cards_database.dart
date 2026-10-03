import 'package:drift/drift.dart';
import 'package:nx_offline/nx_offline_drift.dart';

part 'cards_database.g.dart';

@DataClassName('LocalStudyCardRow')
class LocalStudyCards extends Table {
  TextColumn get notes => text().nullable()();
  TextColumn get contentRef => text().nullable()();
  TextColumn get accountKey => text()();
  IntColumn get remoteId => integer()();
  TextColumn get modelType => text()();
  TextColumn get front => text()();
  TextColumn get back => text()();
  TextColumn get transliteration => text().nullable()();
  TextColumn get audioUrl => text().nullable()();
  TextColumn get audioSha256 => text().nullable()();
  IntColumn get audioBytes => integer().nullable()();
  TextColumn get similarWordGroupsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get examplesJson => text().withDefault(const Constant('[]'))();
  TextColumn get linkedWordIdsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get tagsJson => text()();
  TextColumn get learningStatus =>
      text().withDefault(const Constant('future'))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  TextColumn get scheduleJson => text()();
  TextColumn get reviewHistoryJson => text()();
  BoolColumn get suspended => boolean()();
  IntColumn get sourceBookId => integer().nullable()();
  TextColumn get sourceBookName => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get syncState => text()();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{accountKey, remoteId};
}

@DriftDatabase(tables: <Type>[LocalStudyCards])
class CardsDatabase extends _$CardsDatabase {
  CardsDatabase(super.executor);

  @override
  int get schemaVersion => 17;

  Future<void> createHashSchema() => customStatement('''
    CREATE TABLE IF NOT EXISTS card_sync_hashes (
      account_key TEXT NOT NULL, card_id INTEGER NOT NULL,
      hash TEXT NOT NULL, content_ref TEXT,
      PRIMARY KEY (account_key, card_id)
    )
  ''');

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await createHashSchema();
      await DriftOutboxPersistence.createSchema(this);
    },
    onUpgrade: (migrator, from, to) async {
      // Hard v4 cutover. Retain rejected writes for diagnosis, never replay them.
      await customStatement(
        "CREATE TABLE rejected_card_outbox_v3 AS SELECT * FROM offline_outbox WHERE collection = 'cards'",
      );
      await customStatement(
        "DELETE FROM offline_outbox WHERE collection = 'cards'",
      );
      await customStatement('DROP TABLE local_study_cards');
      await migrator.createAll();
      await createHashSchema();
      await customStatement('DELETE FROM card_sync_hashes');
      await customStatement('DELETE FROM offline_sync_metadata');
      await customStatement(
        "DELETE FROM offline_conflicts WHERE collection = 'cards'",
      );
      await customStatement('DROP TABLE IF EXISTS card_status_body_migrations');
    },
  );
}

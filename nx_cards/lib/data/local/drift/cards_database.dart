import 'package:drift/drift.dart';
import 'package:nx_offline/nx_offline_drift.dart';

part 'cards_database.g.dart';

@DataClassName('LocalCardDeckRow')
class LocalCardDecks extends Table {
  TextColumn get accountKey => text()();
  IntColumn get remoteId => integer()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get language => text().nullable()();
  BoolColumn get archived => boolean()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get serverHash => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{accountKey, remoteId};
}

@DataClassName('LocalStudyCardRow')
class LocalStudyCards extends Table {
  TextColumn get accountKey => text()();
  IntColumn get remoteId => integer()();
  IntColumn get deckId => integer()();
  TextColumn get modelType => text()();
  TextColumn get front => text()();
  TextColumn get back => text()();
  TextColumn get transliteration => text().nullable()();
  TextColumn get audioUrl => text().nullable()();
  TextColumn get tagsJson => text()();
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

@DriftDatabase(tables: <Type>[LocalCardDecks, LocalStudyCards])
class CardsDatabase extends _$CardsDatabase {
  CardsDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await DriftOutboxPersistence.createSchema(this);
    },
  );
}

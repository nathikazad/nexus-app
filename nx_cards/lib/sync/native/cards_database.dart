import 'package:drift/drift.dart';
import 'package:nx_offline/nx_offline_drift.dart';

part 'cards_database.g.dart';

@DataClassName('LocalStudyCardRow')
class LocalStudyCards extends Table {
  TextColumn get accountKey => text()();
  IntColumn get remoteId => integer()();
  TextColumn get modelType => text()();
  TextColumn get front => text()();
  TextColumn get back => text()();
  TextColumn get transliteration => text().nullable()();
  TextColumn get audioUrl => text().nullable()();
  TextColumn get examplesJson => text().withDefault(const Constant('[]'))();
  TextColumn get tagsJson => text()();
  TextColumn get learningStatus =>
      text().withDefault(const Constant('not_started'))();
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
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await DriftOutboxPersistence.createSchema(this);
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(localStudyCards, localStudyCards.examplesJson);
      }
      if (from < 3) {
        // Older app code could accept the current server hash while dropping
        // structured card fields. Invalidate those hashes once so the next
        // lifecycle sync replaces every cached card with the canonical bundle.
        await customStatement('SELECT 1');
      }
      if (from < 4) {
        await customStatement('SELECT 1');
      }
      if (from < 5) {
        // Cue-based schedule/history JSON must be reloaded canonically.
        await customStatement('SELECT 1');
      }
      if (from < 6) {
        await migrator.addColumn(
          localStudyCards,
          localStudyCards.learningStatus,
        );
        await customStatement('SELECT 1');
      }
      if (from == 6) {
        final columns = {
          for (final row in await customSelect(
            'PRAGMA table_info(local_study_cards)',
          ).get())
            row.read<String>('name'),
        };
        if (columns.contains('currently_learning')) {
          await customStatement(
            'ALTER TABLE local_study_cards '
            'RENAME COLUMN currently_learning TO learning_status',
          );
        } else if (!columns.contains('learning_status')) {
          await migrator.addColumn(
            localStudyCards,
            localStudyCards.learningStatus,
          );
        }
        await customStatement(
          "UPDATE local_study_cards SET learning_status = CASE "
          "WHEN learning_status IN ('learning', 'learnt', 'not_started') "
          "THEN learning_status "
          "WHEN learning_status IN (1, '1', 'true') THEN 'learning' "
          "ELSE 'not_started' END",
        );
      }
      if (from < 7) {
        await customStatement('SELECT 1');
      }
      if (from < 8) {
        await migrator.alterTable(TableMigration(localStudyCards));
        await customStatement('DROP TABLE IF EXISTS local_card_decks');
      }
    },
  );
}

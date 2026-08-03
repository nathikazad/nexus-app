import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline_drift.dart';

part 'embedded_offline_tables_test.g.dart';

class TestExpenses extends Table {
  TextColumn get accountKey => text()();
  TextColumn get localId => text()();
  TextColumn get description => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{accountKey, localId};
}

@DriftDatabase(
  tables: <Type>[
    TestExpenses,
    OfflineOutboxEntries,
    OfflineSyncMetadataEntries,
    OfflineConflictEntries,
  ],
)
class TestApplicationDatabase extends _$TestApplicationDatabase {
  TestApplicationDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

void main() {
  test(
    'application domain and outbox rows commit in one transaction',
    () async {
      final database = TestApplicationDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.transaction(() async {
        await database
            .into(database.testExpenses)
            .insert(
              TestExpensesCompanion.insert(
                accountKey: 'expense:nexus-primary:user-1',
                localId: 'expense-1',
                description: 'Lunch',
              ),
            );
        await database
            .into(database.offlineOutboxEntries)
            .insert(
              OfflineOutboxEntriesCompanion.insert(
                operationId: 'operation-1',
                accountKey: 'expense:nexus-primary:user-1',
                collection: 'expenses',
                aggregateId: 'expense-1',
                operationType: 'create',
                payloadJson: '{"description":"Lunch"}',
                status: 'queued',
                createdAt: DateTime.utc(2026, 8, 3),
              ),
            );
      });

      expect(await database.select(database.testExpenses).get(), hasLength(1));
      expect(
        await database.select(database.offlineOutboxEntries).get(),
        hasLength(1),
      );
    },
  );

  test('application domain and outbox rows roll back together', () async {
    final database = TestApplicationDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await expectLater(
      database.transaction(() async {
        await database
            .into(database.testExpenses)
            .insert(
              TestExpensesCompanion.insert(
                accountKey: 'expense:nexus-primary:user-1',
                localId: 'expense-1',
                description: 'Lunch',
              ),
            );
        await database
            .into(database.offlineOutboxEntries)
            .insert(
              OfflineOutboxEntriesCompanion.insert(
                operationId: 'operation-1',
                accountKey: 'expense:nexus-primary:user-1',
                collection: 'expenses',
                aggregateId: 'expense-1',
                operationType: 'create',
                payloadJson: '{"description":"Lunch"}',
                status: 'queued',
                createdAt: DateTime.utc(2026, 8, 3),
              ),
            );
        throw StateError('reject the domain write');
      }),
      throwsStateError,
    );

    expect(await database.select(database.testExpenses).get(), isEmpty);
    expect(await database.select(database.offlineOutboxEntries).get(), isEmpty);
  });
}

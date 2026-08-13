import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';
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

  test('shared persistence replaces, claims, and isolates operations', () async {
    final database = TestApplicationDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const account = AccountIdentity(
      application: 'nx_expense',
      serverId: 'nexus-primary',
      userId: '1',
    );
    const otherAccount = AccountIdentity(
      application: 'nx_expense',
      serverId: 'nexus-primary',
      userId: '2',
    );
    final outbox = DriftOutboxPersistence(
      database: database,
      account: account,
    );
    final otherOutbox = DriftOutboxPersistence(
      database: database,
      account: otherAccount,
    );
    final createdAt = DateTime.utc(2026, 8, 4, 10);

    await outbox.enqueueReplacing(
      PendingMutation(
        operationId: 'first',
        account: account,
        collection: 'expenses',
        entityKey: const EntityKey(localId: 'expense-1', remoteId: 7),
        type: MutationType.update,
        payload: const <String, Object?>{'amount': 10},
        createdAt: createdAt,
      ),
    );
    await outbox.enqueueReplacing(
      PendingMutation(
        operationId: 'replacement',
        account: account,
        collection: 'expenses',
        entityKey: const EntityKey(localId: 'expense-1', remoteId: 7),
        type: MutationType.update,
        payload: const <String, Object?>{'amount': 12},
        createdAt: createdAt.add(const Duration(minutes: 1)),
      ),
    );

    expect((await outbox.pendingMutations()).single.operationId, 'replacement');
    expect(await otherOutbox.pendingMutations(), isEmpty);
    final claimed = await outbox.claimNext(
      workerId: 'worker-1',
      now: createdAt.add(const Duration(minutes: 2)),
      lease: const Duration(minutes: 1),
    );
    expect(claimed?.status, PendingMutationStatus.claimed);
    expect(claimed?.leaseOwner, 'worker-1');
  });
}

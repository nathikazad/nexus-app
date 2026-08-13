import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  const account = AccountIdentity(
    serverId: 'nexus-primary',
    userId: 'user-1',
    application: 'nx_expense',
  );

  test(
    'outbox delivers an Expense mutation through an app-owned handler',
    () async {
      final clock = _Clock(DateTime.utc(2026, 8, 3, 12));
      final store = _ExpenseStore(account);
      final remote = _ExpenseRemote();
      final processor = OutboxProcessor(
        store: store,
        handlers: <MutationHandler>[_ExpenseMutationHandler(remote)],
        clock: clock,
        workerId: 'expense-worker',
        scheduler: RetryScheduler(clock: clock),
      );
      addTearDown(processor.close);
      const expense = _Expense(id: 'expense-1', cents: 1299, category: 'food');
      await store.enqueue(
        PendingMutation(
          operationId: 'op-1',
          account: account,
          collection: 'expenses',
          entityKey: EntityKey(localId: expense.id),
          type: MutationType.update,
          payload: expense.toPayload(),
          createdAt: clock.now(),
        ),
      );

      final result = await processor.process();

      expect(result.succeeded, isTrue);
      expect(remote.rows[expense.id], expense);
      expect(await store.pendingMutations(), isEmpty);
    },
  );

  test('date-partition pull policy remains Expense-owned', () async {
    final day = DateTime.utc(2026, 8, 3);
    final remote = _ExpenseLibrary(<DateTime, List<_Expense>>{
      day: const <_Expense>[
        _Expense(id: 'lunch', cents: 900, category: 'food'),
      ],
    });
    final coordinator = ReconciliationCoordinator<DateTime, List<_Expense>>();
    final fullBarrier = Completer<void>();
    remote.fullBarrier = fullBarrier.future;

    final full = coordinator.runFull(remote.syncAll);
    final openedDay = coordinator.runItem(
      day,
      reconcile: () => remote.syncDay(day),
      readAfterFull: () async => remote.local[day] ?? const <_Expense>[],
    );

    expect(remote.fullFetches, 1);
    expect(remote.dayFetches, 0);
    fullBarrier.complete();
    await full;
    expect(await openedDay, remote.remote[day]);
    expect(remote.dayFetches, 0);
  });
}

final class _Expense {
  const _Expense({
    required this.id,
    required this.cents,
    required this.category,
  });

  final String id;
  final int cents;
  final String category;

  Map<String, Object?> toPayload() => <String, Object?>{
    'id': id,
    'cents': cents,
    'category': category,
  };

  factory _Expense.fromPayload(Map<String, Object?> payload) => _Expense(
    id: payload['id']! as String,
    cents: payload['cents']! as int,
    category: payload['category']! as String,
  );

  @override
  bool operator ==(Object other) =>
      other is _Expense &&
      id == other.id &&
      cents == other.cents &&
      category == other.category;

  @override
  int get hashCode => Object.hash(id, cents, category);
}

final class _ExpenseRemote {
  final Map<String, _Expense> rows = <String, _Expense>{};
}

final class _ExpenseMutationHandler implements MutationHandler {
  const _ExpenseMutationHandler(this.remote);

  final _ExpenseRemote remote;

  @override
  String get collection => 'expenses';

  @override
  Future<MutationReceipt> execute(PendingMutation mutation) async {
    final expense = _Expense.fromPayload(mutation.payload);
    remote.rows[expense.id] = expense;
    return MutationReceipt(
      operationId: mutation.operationId,
      entityKey: mutation.entityKey,
      revision: const Revision('expense-revision-1'),
    );
  }
}

final class _ExpenseStore implements OutboxStore {
  _ExpenseStore(this.account);

  @override
  final AccountIdentity account;
  final List<PendingMutation> _pending = <PendingMutation>[];

  Future<void> enqueue(PendingMutation mutation) async =>
      _pending.add(mutation);

  @override
  Future<PendingMutation?> claimNext({
    required String workerId,
    required DateTime now,
    required Duration lease,
  }) async {
    for (var index = 0; index < _pending.length; index++) {
      final mutation = _pending[index];
      if (!mutation.isEligibleAt(now)) continue;
      final claimed = mutation.copyWith(
        status: PendingMutationStatus.claimed,
        leaseOwner: workerId,
        leaseExpiresAt: now.add(lease),
      );
      _pending[index] = claimed;
      return claimed;
    }
    return null;
  }

  @override
  Future<void> complete(MutationReceipt receipt) async {
    _pending.removeWhere(
      (mutation) => mutation.operationId == receipt.operationId,
    );
  }

  @override
  Future<void> fail(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  }) async {
    throw StateError('The happy-path reuse proof should not fail');
  }

  @override
  Future<DateTime?> nextRetryAt() async => null;

  @override
  Future<List<PendingMutation>> pendingMutations() async =>
      List<PendingMutation>.unmodifiable(_pending);
}

final class _ExpenseLibrary {
  _ExpenseLibrary(this.remote);

  final Map<DateTime, List<_Expense>> remote;
  final Map<DateTime, List<_Expense>> local = <DateTime, List<_Expense>>{};
  Future<void>? fullBarrier;
  var fullFetches = 0;
  var dayFetches = 0;

  Future<void> syncAll() async {
    fullFetches++;
    await fullBarrier;
    local
      ..clear()
      ..addAll(remote);
  }

  Future<List<_Expense>> syncDay(DateTime day) async {
    dayFetches++;
    final rows = remote[day] ?? const <_Expense>[];
    local[day] = rows;
    return rows;
  }
}

final class _Clock implements Clock {
  const _Clock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

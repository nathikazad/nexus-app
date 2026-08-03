import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

import '../support/fakes.dart';

void main() {
  const account = AccountIdentity(
    serverId: 'nexus-primary',
    userId: 'user-1',
    application: 'test',
  );
  late FakeClock clock;
  late MemoryOutboxStore store;
  late _WakeFactory wakes;
  late RetryScheduler scheduler;
  late _MutationHandler handler;
  late OutboxProcessor processor;

  PendingMutation mutation(String id) => PendingMutation(
    operationId: id,
    account: account,
    collection: 'items',
    entityKey: EntityKey(localId: id),
    type: MutationType.update,
    payload: <String, Object?>{'value': id},
    createdAt: clock.now(),
  );

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 8, 3));
    store = MemoryOutboxStore(account);
    wakes = _WakeFactory();
    scheduler = RetryScheduler(clock: clock, wakeFactory: wakes.call);
    handler = _MutationHandler();
    processor = OutboxProcessor(
      store: store,
      handlers: <MutationHandler>[handler],
      clock: clock,
      workerId: 'worker-1',
      scheduler: scheduler,
    );
  });

  tearDown(() => processor.close());

  test('routes and completes every eligible operation', () async {
    await store.enqueue(mutation('one'));
    await store.enqueue(mutation('two'));

    final result = await processor.process();

    expect(result.completedCount, 2);
    expect(result.failureCount, 0);
    expect(handler.seen.map((entry) => entry.operationId), <String>[
      'one',
      'two',
    ]);
    expect(await store.pendingMutations(), isEmpty);
    expect(processor.status.activity, SyncActivity.idle);
  });

  test('concurrent triggers share one processing run', () async {
    await store.enqueue(mutation('one'));
    handler.gate = Completer<void>();

    final first = processor.process();
    final second = processor.process();

    expect(identical(first, second), isTrue);
    handler.gate!.complete();
    await first;
    expect(handler.seen, hasLength(1));
  });

  test('transient failure schedules and performs a durable retry', () async {
    await store.enqueue(mutation('one'));
    handler.failure = const SyncFailure(
      kind: SyncFailureKind.transient,
      message: 'offline',
    );

    final first = await processor.process();

    expect(first.failureCount, 1);
    expect(
      (await store.pendingMutations()).single.status,
      PendingMutationStatus.retryWaiting,
    );
    expect(scheduler.scheduledAt, clock.now().add(const Duration(seconds: 2)));
    expect(wakes.lastDelay, const Duration(seconds: 2));

    handler.failure = null;
    clock.value = clock.value.add(const Duration(seconds: 2));
    final completed = processor.statusChanges.firstWhere(
      (status) => status.activity == SyncActivity.idle,
    );
    wakes.fire();
    await completed;

    expect(await store.pendingMutations(), isEmpty);
    expect(handler.seen, hasLength(2));
    expect(scheduler.scheduledAt, isNull);
  });

  test('validation failure is blocked and is not scheduled forever', () async {
    await store.enqueue(mutation('one'));
    handler.failure = const SyncFailure(
      kind: SyncFailureKind.validation,
      message: 'invalid payload',
    );

    await processor.process();

    expect(
      (await store.pendingMutations()).single.status,
      PendingMutationStatus.blocked,
    );
    expect(processor.status.activity, SyncActivity.blocked);
    expect(scheduler.scheduledAt, isNull);
  });

  test('close waits for an active claimed operation to settle', () async {
    await store.enqueue(mutation('one'));
    handler.gate = Completer<void>();
    final run = processor.process();
    await Future<void>.delayed(Duration.zero);

    var closed = false;
    final closing = processor.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);

    handler.gate!.complete();
    await run;
    await closing;
    expect(closed, isTrue);
    expect(await store.pendingMutations(), isEmpty);
  });
}

final class _MutationHandler implements MutationHandler {
  @override
  String get collection => 'items';

  final List<PendingMutation> seen = <PendingMutation>[];
  Completer<void>? gate;
  SyncFailure? failure;

  @override
  Future<MutationReceipt> execute(PendingMutation mutation) async {
    seen.add(mutation);
    await gate?.future;
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw SyncTransportException(configuredFailure);
    }
    return MutationReceipt(
      operationId: mutation.operationId,
      entityKey: mutation.entityKey,
      revision: const Revision('server-revision'),
    );
  }
}

final class _WakeFactory {
  Duration? lastDelay;
  _FakeWake? wake;

  ScheduledWake call(Duration delay, void Function() callback) {
    lastDelay = delay;
    return wake = _FakeWake(callback);
  }

  void fire() => wake?.fire();
}

final class _FakeWake implements ScheduledWake {
  _FakeWake(this.callback);

  final void Function() callback;
  bool cancelled = false;

  void fire() {
    if (!cancelled) callback();
  }

  @override
  void cancel() => cancelled = true;
}

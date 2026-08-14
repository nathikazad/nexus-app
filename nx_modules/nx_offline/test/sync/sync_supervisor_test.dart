import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test('coalesces many keyed requests into one serialized batch', () async {
    final reconciler = _Reconciler<int>();
    final supervisor = SyncSupervisor<int>(
      reconciler: reconciler,
      coalescingWindow: Duration.zero,
    );
    addTearDown(supervisor.close);

    final requests = <Future<void>>[
      for (var id = 1; id <= 100; id++)
        supervisor.requestKey(id, SyncReason.appStarted),
    ];
    await Future.wait(requests);

    expect(reconciler.maxConcurrent, 1);
    expect(reconciler.keyBatches, [
      <int>{for (var id = 1; id <= 100; id++) id},
    ]);
  });

  test('full request supersedes pending keyed work', () async {
    final reconciler = _Reconciler<int>();
    final supervisor = SyncSupervisor<int>(
      reconciler: reconciler,
      coalescingWindow: Duration.zero,
    );
    addTearDown(supervisor.close);

    final keyed = supervisor.requestKeys({1, 2}, SyncReason.appStarted);
    final full = supervisor.requestFull(SyncReason.manual);
    await Future.wait([keyed, full]);

    expect(reconciler.fullCalls, 1);
    expect(reconciler.keyBatches, isEmpty);
  });

  test('equivalent request during active full shares that run', () async {
    final barrier = Completer<void>();
    final reconciler = _Reconciler<int>(barrier: barrier.future);
    final supervisor = SyncSupervisor<int>(
      reconciler: reconciler,
      coalescingWindow: Duration.zero,
    );
    addTearDown(supervisor.close);

    final first = supervisor.requestFull(SyncReason.appStarted);
    await reconciler.started.future;
    final second = supervisor.requestKey(7, SyncReason.appResumed);
    barrier.complete();
    await Future.wait([first, second]);

    expect(reconciler.fullCalls, 1);
    expect(reconciler.keyBatches, isEmpty);
  });

  test(
    'new keys during active keyed work become one follow-up batch',
    () async {
      final barrier = Completer<void>();
      final reconciler = _Reconciler<int>(barrier: barrier.future);
      final supervisor = SyncSupervisor<int>(
        reconciler: reconciler,
        coalescingWindow: Duration.zero,
      );
      addTearDown(supervisor.close);

      final first = supervisor.requestKey(1, SyncReason.appStarted);
      await reconciler.started.future;
      final rest = <Future<void>>[
        for (var id = 2; id <= 20; id++)
          supervisor.requestKey(id, SyncReason.appStarted),
      ];
      barrier.complete();
      await Future.wait([first, ...rest]);

      expect(reconciler.maxConcurrent, 1);
      expect(reconciler.keyBatches, [
        {1},
        {for (var id = 2; id <= 20; id++) id},
      ]);
    },
  );

  test('preparation runs before each pull', () async {
    final events = <String>[];
    final reconciler = _Reconciler<int>(events: events);
    final supervisor = SyncSupervisor<int>(
      reconciler: reconciler,
      prepare: () async => events.add('prepare'),
      coalescingWindow: Duration.zero,
    );
    addTearDown(supervisor.close);

    await supervisor.requestFull(SyncReason.manual);

    expect(events, ['prepare', 'full']);
  });
}

final class _Reconciler<K> implements PullReconciler<K> {
  _Reconciler({this.barrier, this.events});

  final Future<void>? barrier;
  final List<String>? events;
  final Completer<void> started = Completer<void>();
  final List<Set<K>> keyBatches = <Set<K>>[];
  var fullCalls = 0;
  var concurrent = 0;
  var maxConcurrent = 0;

  @override
  Future<void> pullAll() async {
    fullCalls++;
    events?.add('full');
    await _run();
  }

  @override
  Future<void> pullKeys(Set<K> keys) async {
    keyBatches.add(Set<K>.of(keys));
    events?.add('keys');
    await _run();
  }

  Future<void> _run() async {
    concurrent++;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    if (!started.isCompleted) started.complete();
    await barrier;
    concurrent--;
  }
}

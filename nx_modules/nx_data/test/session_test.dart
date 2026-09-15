import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_data/nx_data.dart';
import 'package:nx_sync/nx_sync.dart';

class Offline implements OfflineSyncBackend {
  final pending = Completer<void>();
  int calls = 0;
  @override
  Future<void> synchronize(SyncReason reason) { calls++; return pending.future; }
}
void main() {
  test('an open view refreshes while the offline library is still downloading', () async {
    final offline = Offline();
    var visible = 0;
    final session = AppDataSession(
      definition: AppDataDefinition(name: 'docs', refreshVisible: () async { visible++; }),
      checkFreshness: (refresh) => refresh(), offline: offline,
      policy: const AppDataPolicy(isWeb: false));
    await session.synchronize(SyncReason.appStarted);
    await Future<void>.delayed(Duration.zero);
    expect(offline.calls, 1);
    await session.synchronize(SyncReason.timer);
    expect(visible, 2);
    expect(offline.pending.isCompleted, isFalse);
    offline.pending.complete();
    await session.close();
  });
  test('web never starts native persistence or downloads', () async {
    final offline = Offline();
    final session = AppDataSession(
      definition: AppDataDefinition(name: 'cards', refreshVisible: () async {}),
      checkFreshness: (refresh) => refresh(), offline: offline,
      policy: const AppDataPolicy(isWeb: true));
    await session.synchronize(SyncReason.appStarted);
    await Future<void>.delayed(Duration.zero);
    expect(offline.calls, 0);
    await session.close();
  });
  test('a failed visible read is not reported as successfully applied', () async {
    final session = AppDataSession(
      definition: AppDataDefinition(name: 'books', refreshVisible: () async { throw StateError('offline'); }),
      checkFreshness: (refresh) => refresh());
    await expectLater(session.synchronize(SyncReason.timer), throwsStateError);
    await session.close();
  });
}

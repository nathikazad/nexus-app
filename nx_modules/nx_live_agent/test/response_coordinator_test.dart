import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_live_agent/src/response_coordinator.dart';

void main() {
  test(
    'reserves before send completes and coalesces overlapping requests',
    () async {
      final sending = Completer<void>();
      var sends = 0;
      final coordinator = ResponseCoordinator(() {
        sends++;
        return sending.future;
      });
      final first = coordinator.request();
      await coordinator.request();
      await coordinator.request();
      expect(sends, 1);
      sending.complete();
      await first;
      coordinator.generationFinished();
      await coordinator.flush();
      expect(sends, 2);
    },
  );
  test('waits for both automatic response generation and playback', () async {
    var sends = 0;
    final coordinator = ResponseCoordinator(() async {
      sends++;
    });
    coordinator.generationStarted();
    coordinator.playbackStarted();
    await coordinator.request();
    coordinator.generationFinished();
    await coordinator.flush();
    expect(sends, 0);
    coordinator.playbackFinished();
    await coordinator.flush();
    expect(sends, 1);
  });
  test('server race retries only after active response finishes', () async {
    var sends = 0;
    final coordinator = ResponseCoordinator(() async {
      sends++;
    });
    await coordinator.request();
    coordinator.conflict();
    await coordinator.flush();
    expect(sends, 1);
    coordinator.generationFinished();
    await coordinator.flush();
    expect(sends, 2);
  });
  test('closing discards pending responses', () async {
    var sends = 0;
    final coordinator = ResponseCoordinator(() async {
      sends++;
    });
    coordinator.generationStarted();
    await coordinator.request();
    coordinator.close();
    coordinator.generationFinished();
    await coordinator.flush();
    expect(sends, 0);
  });
}

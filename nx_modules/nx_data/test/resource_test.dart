import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_data/nx_data.dart';

void main() {
  test(
    'concurrent reads coalesce and refresh preserves previous data on failure',
    () async {
      var calls = 0;
      var failure = false;
      final resource = DataResource<int>(() async {
        calls++;
        if (failure) throw StateError('offline');
        return calls;
      });
      expect(await Future.wait([resource.read(), resource.read()]), [1, 1]);
      expect(await resource.read(), 1);
      failure = true;
      resource.invalidate();
      await expectLater(resource.read(), throwsStateError);
      expect(resource.value, 1);
      expect(resource.stale, true);
    },
  );
  test(
    'a change during a read retries before acknowledging freshness',
    () async {
      final gate = Completer<int>();
      var calls = 0;
      final resource = DataResource<int>(
        () => ++calls == 1 ? gate.future : Future.value(5),
      );
      final read = resource.read();
      resource.invalidate();
      final coalesced = resource.read();
      gate.complete(4);
      expect(await Future.wait([read, coalesced]), [5, 5]);
      expect(calls, 2);
      expect(resource.stale, false);
    },
  );
}

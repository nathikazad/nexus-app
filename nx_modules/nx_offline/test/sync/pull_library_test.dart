import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test('deduplicates catalog and known IDs and awaits bounded pages', () async {
    final pages = <List<int>>[];
    var active = false;
    await pullLibrary<int>(
      discover: () async => List.generate(45, (i) => i),
      knownKeys: [0, 46],
      compare: (a, b) => a.compareTo(b),
      reconcilePage: (keys) async {
        expect(active, false);
        active = true;
        await Future<void>.delayed(Duration.zero);
        pages.add(keys.toList());
        active = false;
      },
    );
    expect(pages.map((p) => p.length), [20, 20, 6]);
    expect(pages.expand((p) => p).toSet().length, 46);
    expect(pages.last.last, 46);
  });

  test(
    'failure stops the run and propagates instead of reporting success',
    () async {
      var calls = 0;
      await expectLater(
        pullLibrary<int>(
          discover: () async => [1, 2, 3],
          pageSize: 1,
          reconcilePage: (_) async {
            calls++;
            if (calls == 2) throw StateError('offline');
          },
        ),
        throwsStateError,
      );
      expect(calls, 2);
    },
  );
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test(
    'deduplicates files, reserves demand capacity, and retries failures',
    () async {
      final queue = AttachmentQueue(concurrency: 2);
      final gate = Completer<int>();
      final started = <String>[];
      final a = queue.run('a', () {
        started.add('a');
        return gate.future;
      });
      final duplicate = queue.run<int>(
        'a',
        () async => throw StateError('duplicate'),
      );
      final b = queue.run('b', () async {
        started.add('b');
        return 2;
      });
      final demand = queue.run('demand', () async {
        started.add('demand');
        return 3;
      }, foreground: true);
      expect(await demand, 3);
      expect(started, ['a', 'demand']);
      gate.complete(1);
      expect(await Future.wait([a, duplicate, b]), [1, 1, 2]);
      await expectLater(
        queue.run('failure', () async => throw StateError('network')),
        throwsStateError,
      );
      expect(await queue.run('failure', () async => 4), 4);
      await queue.close();
      await expectLater(queue.run('closed', () async => 1), throwsStateError);
    },
  );
}

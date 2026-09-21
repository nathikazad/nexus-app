import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/study/lazy_study_queue.dart';

void main() {
  test('first card opens without preparing the remaining queue', () async {
    final reads = <int>[];
    final queue = LazyStudyQueue(40, (index) async {
      reads.add(index);
      return 'card $index';
    });
    expect(await queue.prepare(0), 'card 0');
    expect(reads, [0]);
    await Future.wait([queue.prepare(1), queue.prepare(2)]);
    expect(reads, [0, 1, 2]);
    expect(await queue.prepare(0), 'card 0');
    expect(reads, [0, 1, 2]);
  });
  test('navigation shares in-flight prefetch and failed loads can retry', () async {
    var calls = 0;
    final gate = Completer<String>();
    final queue = LazyStudyQueue(3, (_) {
      calls++;
      return calls == 1 ? gate.future : Future.value('loaded');
    });
    final prefetch = queue.prepare(1);
    final navigation = queue.prepare(1);
    expect(identical(prefetch, navigation), isTrue);
    final failure = expectLater(navigation, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    gate.completeError(StateError('read failed'));
    await failure;
    expect(await queue.prepare(1), 'loaded');
    expect(calls, 2);
  });
  test('closing rejects in-flight results and further requests', () async {
    final gate = Completer<String>();
    final queue = LazyStudyQueue(3, (_) => gate.future);
    final first = queue.prepare(0);
    final rejected = expectLater(first, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    queue.close();
    gate.complete('late card');
    await rejected;
    await expectLater(queue.prepare(1), throwsStateError);
  });
}

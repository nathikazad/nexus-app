import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/hydrate_study_queue.dart';

StudyCard summary(int id) => StudyCard(
  id: id,
  content: BasicCardContent(front: '$id', back: '$id'),
  schedules: const {},
  reviewHistory: const {},
  suspended: false,
).copyWith(isSummary: true);

void main() {
  test(
    'bounded overlapping reads preserve order and deduplicate cards',
    () async {
      final gate = Completer<void>();
      var active = 0;
      var peak = 0;
      final reads = <int>[];
      final cards = [for (var i = 0; i < 20; i++) summary(i), summary(0)];
      final result = hydrateStudyQueue(cards, (card) async {
        reads.add(card.id);
        active++;
        if (active > peak) peak = active;
        await gate.future;
        active--;
        return card.copyWith(isSummary: false);
      });
      expect(reads.length, 8);
      gate.complete();
      final loaded = await result;
      expect(peak, 8);
      expect(reads.length, 20);
      expect(loaded.map((card) => card.id), cards.map((card) => card.id));
      expect(loaded.every((card) => !card.isSummary), isTrue);
    },
  );

  test(
    'read failures propagate instead of returning incomplete queues',
    () async {
      await expectLater(
        hydrateStudyQueue([summary(1)], (_) async {
          throw StateError('missing body');
        }),
        throwsStateError,
      );
    },
  );
}

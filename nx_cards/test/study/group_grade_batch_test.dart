import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/scheduling.dart';
import 'package:nx_cards/study/language/group_grade_batch.dart';
import 'similar_sounds_test.dart' show soundCard;

void main() {
  test(
    'one grade updates all tested words, only this direction, and keeps earlier group history',
    () async {
      final cards = [
        soundCard(1, 'guó', englishScore: 2),
        soundCard(2, 'guǒ'),
        soundCard(3, 'guò'),
      ];
      final latest = {for (final c in cards) c.id: c};
      final scheduler = FsrsCardScheduler();
      final saved = <StudyCard>[];
      final batch = GroupGradeBatch(
        prompts: [
          for (final c in cards.take(2))
            StudyPrompt(card: c, cue: StudyCue.fromAudio),
        ],
        latest: latest,
        scheduler: scheduler,
        now: DateTime.utc(2026, 9, 29),
        rating: CardRating.good,
      );
      await batch.save((c) async {
        saved.add(c);
      }, latest);
      expect(saved, hasLength(2));
      expect(latest[3]!.reviewHistoryFor(StudyCue.fromAudio), isEmpty);
      expect(latest[1]!.reviewHistoryFor(StudyCue.fromLanguage), hasLength(2));
      expect(latest[1]!.reviewHistoryFor(StudyCue.fromAudio).single.rating, 3);
      final next = GroupGradeBatch(
        prompts: [StudyPrompt(card: cards.first, cue: StudyCue.fromAudio)],
        latest: latest,
        scheduler: scheduler,
        now: DateTime.utc(2026, 9, 29, 1),
        rating: CardRating.again,
      );
      await next.save((c) async {
        saved.add(c);
      }, latest);
      expect(
        latest[1]!.reviewHistoryFor(StudyCue.fromAudio).map((r) => r.rating),
        [3, 1],
      );
    },
  );
  test(
    'partial save retries keep review IDs and do not re-grade successful members',
    () async {
      final cards = [soundCard(1, 'yóu'), soundCard(2, 'yóu')];
      final latest = {for (final c in cards) c.id: c};
      final batch = GroupGradeBatch(
        prompts: [
          for (final c in cards) StudyPrompt(card: c, cue: StudyCue.fromAudio),
        ],
        latest: latest,
        scheduler: FsrsCardScheduler(),
        now: DateTime.utc(2026, 9, 29),
        rating: CardRating.again,
      );
      final attempts = <StudyCard>[];
      var fail = true;
      Future<void> save(StudyCard c) async {
        attempts.add(c);
        if (c.id == 2 && fail) throw StateError('offline');
      }

      await expectLater(batch.save(save, latest), throwsStateError);
      fail = false;
      await batch.save(save, latest);
      await batch.save(save, latest);
      expect(attempts.map((c) => c.id), [1, 2, 2]);
      expect(identical(attempts[1], attempts[2]), isTrue);
      expect(
        latest.values.every(
          (c) => c.reviewHistoryFor(StudyCue.fromAudio).single.rating == 1,
        ),
        isTrue,
      );
    },
  );
}

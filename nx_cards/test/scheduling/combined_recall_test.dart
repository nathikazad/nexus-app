import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/card_scheduler.dart';
import 'package:nx_cards/scheduling/retention.dart';
import 'package:nx_cards/study/language/group_grade_batch.dart';

StudyCard word(bool spokenOnly) => StudyCard(
  id: 10,
  suspended: false,
  learningStatus: LearningStatus.recall,
  content: LanguageCardContent(
    english: 'cat',
    originalScript: '猫',
    transliteration: 'māo',
    audioUrl: '/cat.mp3',
    spokenOnly: spokenOnly,
  ),
  schedules: {
    for (final cue in StudyCue.languageDirections)
      cue: const CardSchedule.initial(enabled: true),
  },
  reviewHistory: const {},
);

void main() {
  for (final spokenOnly in [false, true]) {
    for (final writing in [false, true]) {
      test('combined round and grades: spoken=$spokenOnly writing=$writing', () {
        final card = word(spokenOnly);
        final questions = combineRecallPrompts(
          retentionPrompts(
            [card],
            RecallComponent.values.toSet(),
            writing: writing,
          ),
        );
        expect(questions.length, spokenOnly ? 2 : 3);
        final expected = {
          RecallComponent.meaning: {
            StudyCue.meaningToSound,
            if (writing && !spokenOnly) StudyCue.meaningToScript,
          },
          RecallComponent.sound: {
            StudyCue.soundToMeaning,
            if (writing && !spokenOnly) StudyCue.soundToScript,
          },
          if (!spokenOnly)
            RecallComponent.script: {
              StudyCue.scriptToMeaning,
              StudyCue.scriptToSound,
            },
        };
        for (final prompt in questions) {
          expect(prompt.testedCues, expected[prompt.cue.source]);
          expect(prompt.withCard(card).testedCues, prompt.testedCues);
          expect(
            prompt.recallsTarget,
            writing &&
                !spokenOnly &&
                prompt.cue.source != RecallComponent.script,
          );
          for (final rating in [CardRating.again, CardRating.good]) {
            var serial = 0;
            final scheduler = FsrsCardScheduler(
              reviewId: () => 'review-${serial++}',
            );
            final now = DateTime.utc(2026, 10, 3);
            final updated = scheduler.preview(prompt, now)[rating]!.card;
            for (final cue in StudyCue.languageDirections) {
              if (prompt.testedCues.contains(cue)) {
                expect(
                  updated.reviewHistoryFor(cue).single.rating,
                  rating.fsrsValue,
                );
                expect(updated.scheduleFor(cue).reviewCount, 1);
                // Each schedule matches a standalone FSRS update for that direction.
                final individual = scheduler
                    .preview(StudyPrompt(card: card, cue: cue), now)[rating]!
                    .card;
                expect(
                  updated.scheduleFor(cue).dueAt,
                  individual.scheduleFor(cue).dueAt,
                );
                expect(
                  updated.scheduleFor(cue).stability,
                  individual.scheduleFor(cue).stability,
                );
              } else {
                expect(updated.reviewHistoryFor(cue), isEmpty);
                expect(updated.scheduleFor(cue), same(card.scheduleFor(cue)));
              }
            }
          }
        }
      });
    }
  }
  test('grouping preserves filtered directions and is idempotent', () {
    final card = word(false);
    final input = [StudyPrompt(card: card, cue: StudyCue.scriptToSound)];
    final grouped = combineRecallPrompts([...input, ...input]);
    expect(grouped, hasLength(1));
    expect(grouped.single.testedCues, {StudyCue.scriptToSound});
    expect(combineRecallPrompts(grouped).single.testedCues, {
      StudyCue.scriptToSound,
    });
  });
  test(
    'a failed save retries the same complete aggregate without duplicate reviews',
    () async {
      final card = word(false);
      final prompt = combineRecallPrompts([
        StudyPrompt(card: card, cue: StudyCue.meaningToSound),
        StudyPrompt(card: card, cue: StudyCue.meaningToScript),
      ]).single;
      final latest = {card.id: card};
      final batch = GroupGradeBatch(
        prompts: [prompt],
        latest: latest,
        scheduler: FsrsCardScheduler(),
        now: DateTime.utc(2026, 10, 3),
        rating: CardRating.good,
      );
      StudyCard? attempted;
      await expectLater(
        batch.save((updated) async {
          attempted = updated;
          throw StateError('offline');
        }, latest),
        throwsStateError,
      );
      await batch.save((updated) async {
        expect(updated, same(attempted));
      }, latest);
      expect(batch.complete, isTrue);
      for (final cue in prompt.testedCues) {
        expect(latest[card.id]!.reviewHistoryFor(cue), hasLength(1));
      }
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_mapper.dart';
import 'package:nx_cards/scheduling/card_scheduler.dart';
import 'package:nx_db/kgql.dart';

StudyCard fresh({bool language = true}) => StudyCard(
  id: 1,
  content: language
      ? const LanguageCardContent(
          english: 'cat',
          originalScript: '猫',
          transliteration: 'māo',
          audioUrl: '/cat',
        )
      : const BasicCardContent(front: 'Q', back: 'A'),
  schedules: {
    for (final cue
        in (language
            ? StudyCue.languageDirections
            : StudyCue.genericDirections))
      cue: CardSchedule.initial(
        enabled: language || cue == StudyCue.frontToBack,
      ),
  },
  reviewHistory: {},
  suspended: false,
);
void main() {
  test(
    'all six outcomes update exactly one history and schedule and serialize v4',
    () {
      var card = fresh();
      final scheduler = FsrsCardScheduler(
        reviewId: () => 'r-${card.reviewHistory.length}',
      );
      for (final cue in StudyCue.languageDirections) {
        final before = card;
        card = scheduler
            .preview(
              StudyPrompt(card: card, cue: cue),
              DateTime.utc(2026, 10),
            )[CardRating.good]!
            .card;
        expect(card.reviewHistoryFor(cue), hasLength(1));
        expect(card.scheduleFor(cue).reviewCount, 1);
        for (final other in card.directions.where((d) => d != cue)) {
          expect(card.scheduleFor(other), same(before.scheduleFor(other)));
          expect(card.reviewHistoryFor(other), before.reviewHistoryFor(other));
        }
      }
      final schedule = scheduleJson(card), history = reviewHistoryJson(card);
      expect(schedule['version'], 4);
      expect(history['version'], 4);
      expect(
        (schedule['cues'] as Map).keys.toSet(),
        StudyCue.languageDirections.map((c) => c.storageKey).toSet(),
      );
      expect((history['items'] as List).length, 6);
      final roundTrip = studyCardFromModel(
        Model(
          id: 1,
          name: 'cat',
          modelTypeId: 1,
          modelType: ModelType(id: 1, name: 'LanguageFlashcard'),
          attributes: {
            'card_details': cardDetailsJson(card.content),
            'language_details': languageDetailsJson(
              card.content as LanguageCardContent,
            ),
            'schedule': schedule,
            'review_history': history,
          },
        ),
      )!;
      expect(reviewHistoryJson(roundTrip), history);
      expect(scheduleJson(roundTrip), schedule);
    },
  );
  test(
    'book serialization has only generic cues with forward enabled by default',
    () {
      final card = fresh(language: false);
      expect((scheduleJson(card)['cues'] as Map).keys.toSet(), {
        'front_to_back',
        'back_to_front',
      });
      expect(card.prompts.single.cue, StudyCue.frontToBack);
      expect(
        () => FsrsCardScheduler().preview(
          StudyPrompt(card: card, cue: StudyCue.meaningToSound),
          DateTime.now(),
        ),
        throwsStateError,
      );
    },
  );
  for (final field in ['schedule', 'review_history']) {
    test('rejects a v3 $field rather than guessing a history conversion', () {
      expect(
        () => studyCardFromModel(
          Model(
            id: 1,
            name: 'old',
            modelTypeId: 1,
            modelType: ModelType(id: 1, name: 'LanguageFlashcard'),
            attributes: {
              field: {'version': 3},
            },
          ),
        ),
        throwsFormatException,
      );
    });
  }
}

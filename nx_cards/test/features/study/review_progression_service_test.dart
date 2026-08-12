import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/settings/review_progression_settings.dart';
import 'package:nx_cards/features/study/review_progression_service.dart';

void main() {
  test('combines cues and promotes 5 of 5 with same-category replacement', () {
    final promoted = _card(
      id: 1,
      category: 'Noun',
      status: LearningStatus.learning,
      ratings: const {
        StudyCue.fromLanguage: [3, 3, 3],
        StudyCue.toLanguage: [4, 4],
      },
    );
    final firstFuture = _card(
      id: 2,
      category: 'Noun',
      status: LearningStatus.notStarted,
    );
    final secondFuture = _card(
      id: 3,
      category: 'Noun',
      status: LearningStatus.notStarted,
    );
    final otherCategory = _card(
      id: 4,
      category: 'Verb',
      status: LearningStatus.notStarted,
    );

    final plan = planReviewProgression(
      reviewedCards: [promoted],
      allCards: [promoted, firstFuture, secondFuture, otherCategory],
      settings: const ReviewProgressionSettings(),
    );

    expect(plan.movedToPast, 1);
    expect(plan.replacements, 1);
    expect(plan.changes.map((change) => change.card.id), [1, 2]);
    expect(plan.changes.last.status, LearningStatus.learning);
  });

  test('moves a 3 of 5 card to Current and leaves 4 of 5 unchanged', () {
    final weak = _card(
      id: 1,
      category: 'Noun',
      status: LearningStatus.learnt,
      ratings: const {
        StudyCue.fromLanguage: [3, 3, 3, 1, 1],
      },
    );
    final middle = _card(
      id: 2,
      category: 'Noun',
      status: LearningStatus.learning,
      ratings: const {
        StudyCue.fromLanguage: [3, 3, 3, 3, 1],
      },
    );

    final plan = planReviewProgression(
      reviewedCards: [weak, middle],
      allCards: [weak, middle],
      settings: const ReviewProgressionSettings(),
    );

    expect(plan.changes, hasLength(1));
    expect(plan.changes.single.card.id, 1);
    expect(plan.changes.single.status, LearningStatus.learning);
  });

  test('waits for a full window and honors the master switch', () {
    final card = _card(
      id: 1,
      category: 'Noun',
      status: LearningStatus.learning,
      ratings: const {
        StudyCue.fromLanguage: [4, 4, 4, 4],
      },
    );
    final incomplete = planReviewProgression(
      reviewedCards: [card],
      allCards: [card],
      settings: const ReviewProgressionSettings(),
    );
    final disabled = planReviewProgression(
      reviewedCards: [card],
      allCards: [card],
      settings: const ReviewProgressionSettings(
        automaticProgressionEnabled: false,
        historyWindow: 4,
      ),
    );

    expect(incomplete.changed, isFalse);
    expect(disabled.changed, isFalse);
  });

  test('promotes and replaces Script cards as one model-type cohort', () {
    final promoted = _card(
      id: 1,
      category: 'Script',
      status: LearningStatus.learning,
      script: true,
      ratings: const {
        StudyCue.fromLanguage: [3, 3, 3, 3, 3],
      },
    );
    final replacement = _card(
      id: 2,
      category: 'Script',
      status: LearningStatus.notStarted,
      script: true,
    );

    final plan = planReviewProgression(
      reviewedCards: [promoted],
      allCards: [promoted, replacement],
      settings: const ReviewProgressionSettings(),
    );

    expect(plan.changes.map((change) => change.card.id), [1, 2]);
    expect(plan.movedToPast, 1);
    expect(plan.replacements, 1);
  });
}

StudyCard _card({
  required int id,
  required String category,
  required LearningStatus status,
  bool script = false,
  Map<StudyCue, List<int>> ratings = const {},
}) {
  var minute = 0;
  final history = <StudyCue, List<CardReview>>{};
  for (final cue in StudyCue.values) {
    history[cue] = [
      for (final rating in ratings[cue] ?? const <int>[])
        CardReview(
          id: '$id-${minute + 1}',
          reviewedAt: DateTime.utc(2026, 8, 1, 12, minute++),
          rating: rating,
          elapsedSeconds: 1,
          scheduledSeconds: 1,
        ),
    ];
  }
  return StudyCard(
    id: id,
    content: LanguageCardContent(
      english: 'word $id',
      originalScript: 'വാക്ക് $id',
      transliteration: 'vākku $id',
    ),
    deckId: 1,
    deckName: 'Malayalam',
    schedules: const {
      StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
    },
    reviewHistory: history,
    suspended: false,
    learningStatus: status,
    modelTypeName: script ? 'Script' : 'Word',
    tags: script
        ? const <String, List<String>>{}
        : <String, List<String>>{
            'Word Category': [category],
          },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/review_progression.dart';
import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:nx_cards/scheduling/review_progression_service.dart';

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
      scope: const StudyScope(language: 'Malayalam', tag: 'Noun'),
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

  test(
    'promotes and replaces Script cards in the selected Script category',
    () {
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
        scope: const StudyScope(language: 'Malayalam', tag: 'Script'),
      );

      expect(plan.changes.map((change) => change.card.id), [1, 2]);
      expect(plan.movedToPast, 1);
      expect(plan.replacements, 1);
    },
  );

  test('uses the fixed window and Book relation as a progression cohort', () {
    final reviewed = _bookCard(
      id: 1,
      status: LearningStatus.learnt,
      ratings: const [3, 1],
    );
    final future = _bookCard(id: 2, status: LearningStatus.notStarted);

    final plan = planReviewProgression(
      reviewedCards: [reviewed],
      allCards: [reviewed, future],
      settings: const ReviewProgressionSettings(),
    );

    expect(plan.changes, hasLength(1));
    expect(plan.changes.single.card.id, 1);
    expect(plan.changes.single.status, LearningStatus.learning);
  });
  test('replacement uses selected Script rather than the first Noun tag', () {
    final promoted =
        _card(
          id: 1,
          category: 'Noun',
          status: LearningStatus.learning,
          ratings: const {
            StudyCue.fromLanguage: [3, 3, 3, 3, 3],
          },
        ).withTags(
          tags: const {
            'Language': ['Malayalam'],
            'Category': ['Noun', 'Script'],
          },
        );
    final noun = _card(
      id: 2,
      category: 'Noun',
      status: LearningStatus.notStarted,
    );
    final script = _card(
      id: 3,
      category: 'Script',
      status: LearningStatus.notStarted,
    );
    final plan = planReviewProgression(
      reviewedCards: [promoted],
      allCards: [promoted, noun, script],
      settings: const ReviewProgressionSettings(),
      scope: const StudyScope(language: 'Malayalam', tag: 'Script'),
    );
    expect(plan.changes.map((c) => c.card.id), [1, 3]);
  });
  test('collection replacements stay within both collection and language', () {
    final promoted =
        _card(
          id: 1,
          category: 'Phrase',
          status: LearningStatus.learning,
          ratings: const {
            StudyCue.fromLanguage: [3, 3, 3, 3, 3],
          },
        ).withTags(
          tags: const {
            'Language': ['Tamil'],
            'Category': ['Phrase'],
            'Collection': ['Family'],
          },
        );
    final otherCollection = promoted.withTags(
      learningStatus: LearningStatus.notStarted,
      tags: const {
        'Language': ['Tamil'],
        'Category': ['Phrase'],
        'Collection': ['Travel'],
      },
    );
    final candidates = [
      _card(
        id: 2,
        category: 'Phrase',
        status: LearningStatus.notStarted,
      ).withTags(tags: otherCollection.tags),
      _card(
        id: 3,
        category: 'Noun',
        status: LearningStatus.notStarted,
      ).withTags(
        tags: const {
          'Language': ['Chinese'],
          'Category': ['Noun'],
          'Collection': ['Family'],
        },
      ),
      _card(
        id: 4,
        category: 'Noun',
        status: LearningStatus.notStarted,
      ).withTags(
        tags: const {
          'Language': ['Tamil'],
          'Category': ['Noun'],
          'Collection': ['Family'],
        },
      ),
    ];
    final plan = planReviewProgression(
      reviewedCards: [promoted],
      allCards: [promoted, ...candidates],
      settings: const ReviewProgressionSettings(),
      scope: const StudyScope(
        language: 'Tamil',
        tagSystem: 'Collection',
        tag: 'Family',
      ),
    );
    expect(plan.changes.map((c) => c.card.id), [1, 4]);
    final noSelection = planReviewProgression(
      reviewedCards: [promoted],
      allCards: [promoted, ...candidates],
      settings: const ReviewProgressionSettings(),
    );
    expect(noSelection.movedToPast, 1);
    expect(noSelection.replacements, 0);
  });
}

StudyCard _bookCard({
  required int id,
  required LearningStatus status,
  List<int> ratings = const [],
}) => StudyCard(
  id: id,
  content: BasicCardContent(front: 'question $id', back: 'answer $id'),
  schedules: const {StudyCue.fromLanguage: CardSchedule.initial(enabled: true)},
  reviewHistory: {
    StudyCue.fromLanguage: [
      for (final (index, rating) in ratings.indexed)
        CardReview(
          id: 'book-$id-$index',
          reviewedAt: DateTime.utc(2026, 8, index + 1),
          rating: rating,
          elapsedSeconds: 1,
          scheduledSeconds: 1,
        ),
    ],
  },
  suspended: false,
  learningStatus: status,
  sourceBookId: 4195,
  sourceBookName: 'The Four Steps to the Epiphany',
  modelTypeName: 'Flashcard',
);

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
    schedules: const {
      StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
    },
    reviewHistory: history,
    suspended: false,
    learningStatus: status,
    modelTypeName: script ? 'Script' : 'Word',
    tags: script
        ? const <String, List<String>>{
            'Language': ['Malayalam'],
          }
        : <String, List<String>>{
            'Language': ['Malayalam'],
            'Word Category': [category],
          },
  );
}

extension _TaggedFixture on StudyCard {
  StudyCard withTags({
    required Map<String, List<String>> tags,
    LearningStatus? learningStatus,
  }) => StudyCard(
    id: id,
    content: content,
    schedules: schedules,
    reviewHistory: reviewHistory,
    suspended: suspended,
    learningStatus: learningStatus ?? this.learningStatus,
    tags: tags,
    modelTypeName: 'LanguageFlashcard',
  );
}

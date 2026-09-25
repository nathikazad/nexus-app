import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/future_card_rank.dart';

StudyCard item(
  int id, {
  String category = 'Script',
  Set<int> links = const {},
  bool active = false,
  int successes = 0,
  String language = 'Chinese',
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    english: '$id',
    originalScript: '$id',
    transliteration: '',
  ),
  schedules: const {},
  suspended: false,
  learningStatus: active ? LearningStatus.active : LearningStatus.inactive,
  tags: {
    'Language': [language],
    'Category': [category],
  },
  linkedWordIds: links,
  reviewHistory: {
    StudyCue.fromLanguage: [
      for (var i = 0; i < successes; i++)
        CardReview(
          id: '$id-$i',
          reviewedAt: DateTime.utc(2026, 1, i + 1),
          rating: 3,
          elapsedSeconds: 0,
          scheduledSeconds: 0,
        ),
    ],
  },
);
Map<int, double> score(
  List<StudyCard> cards, {
  StudyCue cue = StudyCue.fromLanguage,
  int window = 10,
}) => futureCardScores(cards, cue: cue, historyWindow: window);
void main() {
  test('counts each phrase once through nested and repeated paths', () {
    final cards = [
      item(1),
      item(2, category: 'Noun', links: {1}),
      item(3, category: 'Phrase', links: {1, 2}),
      item(4, category: 'Phrase', links: {2}),
    ];
    final scores = score(cards);
    expect(scores[1], closeTo(80, 1e-9));
    expect(scores[2], closeTo(60, 1e-9));
    expect(scores[3], closeTo(60, 1e-9));
    expect(scores[4], closeTo(60, 1e-9));
  });
  test('approved formula responds to mastery, direction, and window', () {
    final cards = [
      item(1, active: true, successes: 4),
      item(2, active: true, successes: 8),
      item(3, category: 'Phrase', links: {1, 2}),
      item(4, category: 'Phrase', links: {2}),
    ];
    final u = (math.log(2) / math.log(3) + 1) / 2;
    expect(
      score(cards)[3],
      closeTo(100 * u * (.6 + .4 * ((.55 + 1) / 2)), 1e-9),
    );
    expect(score(cards, window: 5)[3], closeTo(100 * u, 1e-9));
    expect(
      score(cards, cue: StudyCue.toLanguage)[3],
      closeTo(100 * u * .64, 1e-9),
    );
  });
  test(
    'normalization is isolated by language and candidate activation does not filter corpus',
    () {
      final cards = [
        item(1),
        item(2, category: 'Phrase', links: {1}, active: true),
      ];
      final before = score(cards);
      final after = score([
        ...cards,
        item(3, language: 'Tamil'),
        for (var id = 4; id < 20; id++)
          item(id, language: 'Tamil', category: 'Phrase', links: {3}),
      ]);
      expect(after[1], before[1]);
      expect(after[2], before[2]);
    },
  );
  test(
    'no phrases, missing links, and cycles are safe; ties use stable IDs',
    () {
      expect(score([item(1), item(2)])[1], 0);
      final cards = [
        item(1, links: {2}),
        item(2, links: {1}),
        item(3, category: 'Phrase', links: {1, 999}),
      ];
      expect(
        score(cards).values.every((s) => s.isFinite && s >= 0 && s <= 100),
        isTrue,
      );
      expect(
        sortFutureCards([item(9), item(2)], {9: 0, 2: 0}).map((c) => c.id),
        [2, 9],
      );
    },
  );
}

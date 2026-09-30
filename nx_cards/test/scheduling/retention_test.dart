import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/retention.dart';
import '../study/study_setup_page_test.dart' show sample;

StudyCard scored(int id, List<int> correct) => sample(id, 0).copyWith(
  content: LanguageCardContent(
    english: 'word $id',
    originalScript: '字',
    transliteration: 'zi',
    audioUrl: 'https://example.org/audio.mp3',
  ),
  reviewHistory: {
    for (var direction = 0; direction < 3; direction++)
      StudyCue.activeDirections[direction]: [
        for (var i = 0; i < 5; i++)
          CardReview(
            id: '$id-$direction-$i',
            reviewedAt: DateTime.utc(2026, 1, i + 1),
            rating: i < correct[direction] ? 3 : 1,
            elapsedSeconds: 0,
            scheduledSeconds: 0,
          ),
      ],
  },
);
void main() {
  final all = StudyCue.activeDirections.toSet();
  test('averages the selected direction scores, not pooled attempts', () {
    final card = scored(1, [4, 2, 3]);
    expect(averageRetention(card, all), closeTo(.6, 1e-9));
    expect(averageRetention(card, [StudyCue.fromLanguage]), .8);
    expect(
      averageRetention(card, [StudyCue.fromAudio, StudyCue.toLanguage]),
      .5,
    );
    final unequal = card.copyWith(
      reviewHistory: {
        ...card.reviewHistory,
        StudyCue.fromAudio: card
            .reviewHistoryFor(StudyCue.fromAudio)
            .take(1)
            .toList(),
      },
    );
    expect(
      averageRetention(unequal, [StudyCue.fromLanguage, StudyCue.fromAudio]),
      .5,
    );
  });
  test('27 cards yield 81, 54, or 27 unique recall items', () {
    final cards = [
      for (var i = 0; i < 27; i++) scored(i, [4, 2, 3]),
    ];
    for (var size = 1; size <= 3; size++) {
      final prompts = retentionPrompts(
        cards,
        StudyCue.activeDirections.take(size).toSet(),
      );
      expect(prompts.length, 27 * size);
      expect(prompts.map((p) => (p.cardId, p.cue)).toSet().length, 27 * size);
    }
  });
  test(
    'average filter admits all selected directions then sorts weakest first',
    () {
      final cards = [
        scored(1, [4, 2, 3]),
        scored(2, [1, 5, 5]),
      ];
      final prompts = retentionPrompts(cards, all, maximum: .65);
      expect(prompts.map((p) => p.cardId).toSet(), {1});
      expect(prompts.map((p) => p.cue), [
        StudyCue.fromAudio,
        StudyCue.toLanguage,
        StudyCue.fromLanguage,
      ]);
      expect(retentionCards(cards, {StudyCue.fromLanguage}).map((c) => c.id), [
        2,
        1,
      ]);
      expect(retentionCards(cards, {StudyCue.fromAudio}).map((c) => c.id), [
        1,
        2,
      ]);
    },
  );
  test(
    '80 percent belongs only to Strong; inactive or unsupported prompts excluded',
    () {
      final cards = [
        scored(1, [4, 4, 4]),
        scored(2, [3, 3, 3]),
      ];
      expect(
        retentionCards(
          cards,
          all,
          maximum: .8,
          weakOnly: true,
        ).map((c) => c.id),
        [2],
      );
      expect(retentionCards(cards, all, minimum: .8).map((c) => c.id), [1]);
      expect(retentionPrompts([sample(3, 0)], all).length, 2);
      expect(
        retentionPrompts([
          sample(4, 0, prep: true),
          sample(5, 0, active: false),
          cards.first.copyWith(suspended: true),
        ], all),
        isEmpty,
      );
    },
  );
}

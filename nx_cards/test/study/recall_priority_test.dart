import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/recall_priority.dart';
import 'study_setup_page_test.dart' show sample;

void main() {
  test('repeated fronts preserve every item and maximize the gap', () {
    final ids = [2, 1, 1, 3, 2, 3, 4];
    final prompts = [
      for (var i = 0; i < ids.length; i++)
        StudyPrompt(
          card: sample(ids[i], 0),
          cue: StudyCue.activeDirections[i % 3],
        ),
    ];
    final spaced = spaceRepeatedRecallCards(prompts);
    expect(spaced, unorderedEquals(prompts));
    final last = <int, int>{};
    for (var i = 0; i < spaced.length; i++) {
      if (last.containsKey(spaced[i].cardId)) {
        expect(i - last[spaced[i].cardId]!, greaterThanOrEqualTo(4));
      }
      last[spaced[i].cardId] = i;
    }
  });
  test('no adjacent repeats whenever the selected counts permit it', () {
    for (var a = 1; a <= 3; a++) {
      for (var b = 0; b <= 3; b++) {
        for (var c = 0; c <= 3; c++) {
          for (var seed = 0; seed < 20; seed++) {
            final prompts = [
              for (var id = 0; id < 3; id++)
                for (var n = 0; n < [a, b, c][id]; n++)
                  StudyPrompt(
                    card: sample(id, 0),
                    cue: StudyCue.activeDirections[n],
                  ),
            ]..shuffle(Random(seed));
            final result = spaceRepeatedRecallCards(prompts);
            expect(result, unorderedEquals(prompts));
            if ([a, b, c].reduce(max) <= (prompts.length + 1) ~/ 2) {
              for (var i = 1; i < result.length; i++) {
                expect(result[i].cardId, isNot(result[i - 1].cardId));
              }
            }
          }
        }
      }
    }
  });

  test('selects weakest items before shuffling, preserving cues and count', () {
    final prompts = [
      for (var id = 1; id <= 10; id++)
        StudyPrompt(card: sample(id, id - 1), cue: StudyCue.fromLanguage),
    ];
    prioritizeRecallPrompts(prompts, DateTime.utc(2026), historyWindow: 10);
    final selected = shuffledRecallSelection(prompts, 5, random: Random(8));
    expect(selected.map((p) => p.cardId), unorderedEquals([1, 2, 3, 4, 5]));
    expect(selected.map((p) => p.cardId).toList(), isNot([1, 2, 3, 4, 5]));
  });

  final now = DateTime.utc(2026, 9, 24);
  StudyPrompt past(
    int id,
    int correct, {
    double stability = 10,
    int days = 10,
  }) {
    final card = sample(id, correct);
    return StudyPrompt(
      card: card.copyWith(
        schedules: {
          ...card.schedules,
          StudyCue.fromLanguage: card
              .scheduleFor(StudyCue.fromLanguage)
              .copyWith(
                stability: stability,
                lastReviewedAt: now.subtract(Duration(days: days)),
                dueAt: now.subtract(const Duration(days: 1)),
              ),
        },
      ),
      cue: StudyCue.fromLanguage,
    );
  }

  test('80 percent accuracy gives a 20 percent boost at equal FSRS risk', () {
    final perfect = pastRecallPriority(past(1, 10), now, historyWindow: 10);
    final base = past(2, 8);
    final weakerCard = base.card.copyWith(
      reviewHistory: {
        ...base.card.reviewHistory,
        StudyCue.fromLanguage: [
          ...base.reviewHistory,
          for (var i = 0; i < 2; i++)
            CardReview(
              id: 'miss-$i',
              reviewedAt: DateTime.utc(2026, 2, i + 1),
              rating: 1,
              elapsedSeconds: 0,
              scheduledSeconds: 0,
            ),
        ],
      },
    );
    final weaker = pastRecallPriority(
      base.withCard(weakerCard),
      now,
      historyWindow: 10,
    );
    expect(perfect, greaterThan(0));
    expect(weaker, closeTo(perfect * 1.2, 0.000001));
    expect(
      pastRecallPriority(past(3, 8), now, historyWindow: 8),
      closeTo(perfect, 0.000001),
    );
  });

  test(
    'equal scores use a shuffled tie order, independent of ID and urgency',
    () {
      final prompts = [
        for (var id = 1; id <= 30; id++) past(id, 10, stability: id.toDouble()),
      ];
      final expected = List<StudyPrompt>.of(prompts)..shuffle(Random(17));
      prioritizeRecallPrompts(
        prompts,
        now,
        historyWindow: 10,
        random: Random(17),
      );
      expect(prompts, orderedEquals(expected));
      expect(
        prompts.take(7).map((p) => p.cardId).toList(),
        isNot([1, 2, 3, 4, 5, 6, 7]),
      );
    },
  );

  test(
    'tied front types are sampled across the pool before the round limit',
    () {
      final original = [
        for (var id = 1; id <= 30; id++)
          for (final cue in StudyCue.activeDirections)
            StudyPrompt(card: sample(id, 0), cue: cue),
      ];
      final selections = <String>{};
      for (var seed = 0; seed < 10; seed++) {
        final prompts = List<StudyPrompt>.of(original);
        prioritizeRecallPrompts(
          prompts,
          now,
          historyWindow: 10,
          random: Random(seed),
        );
        final chosen = shuffledRecallSelection(
          prompts,
          7,
          random: Random(seed),
        );
        expect(chosen, hasLength(7));
        expect(
          chosen.map((p) => '${p.cardId}:${p.cue.name}').toSet(),
          hasLength(7),
        );
        selections.add(
          chosen.map((p) => '${p.cardId}:${p.cue.name}').join(','),
        );
        expect(chosen.any((p) => p.cardId > 3), isTrue);
      }
      expect(selections, hasLength(10));
    },
  );

  test('weakest cards precede stronger due cards', () {
    final prompts = [
      for (var id = 1; id <= 12; id++)
        StudyPrompt(
          card: sample(id, id < 7 ? 0 : 2),
          cue: StudyCue.fromLanguage,
        ),
      for (var id = 13; id <= 16; id++)
        StudyPrompt(card: sample(id, 8), cue: StudyCue.fromLanguage),
      StudyPrompt(card: sample(17, 10, due: false), cue: StudyCue.fromLanguage),
    ];
    prioritizeRecallPrompts(prompts, DateTime.now(), historyWindow: 10);
    expect(prompts.length, 17);
    expect(prompts.take(6).map((p) => p.cardId).toSet(), {1, 2, 3, 4, 5, 6});
    expect(prompts.take(10).length, 10);
    expect(
      prompts
          .take(10)
          .where((p) => isPastDue(p, DateTime.now(), historyWindow: 10))
          .length,
      0,
    );
    expect(prompts.map((p) => p.cardId), contains(17));
  });
  test('due priority follows the selected direction', () {
    final prompt = StudyPrompt(card: sample(1, 8), cue: StudyCue.toLanguage);
    expect(isPastDue(prompt, DateTime.now(), historyWindow: 10), isFalse);
  });
}

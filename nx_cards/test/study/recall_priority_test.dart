import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/recall_priority.dart';
import 'study_setup_page_test.dart' show sample;

void main() {
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
    final weaker = pastRecallPriority(past(2, 8), now, historyWindow: 10);
    expect(perfect, greaterThan(0));
    expect(weaker, closeTo(perfect * 1.2, 0.000001));
    expect(
      pastRecallPriority(past(3, 8), now, historyWindow: 8),
      closeTo(perfect, 0.000001),
    );
  });

  test('FSRS urgency can outweigh weaker recent accuracy', () {
    final urgent = past(1, 10, days: 100);
    final recent = past(2, 8, days: 1);
    final prompts = [recent, urgent];
    prioritizeRecallPrompts(prompts, now, historyWindow: 10);
    expect(prompts.first.cardId, 1);
  });

  test('selects ten highest forgetting risks out of 100 Past cards', () {
    final prompts = [
      for (var id = 100; id >= 1; id--) past(id, 10, stability: id.toDouble()),
    ];
    prioritizeRecallPrompts(prompts, now, historyWindow: 10);
    expect(
      prompts.take(10).map((p) => p.cardId),
      List.generate(10, (i) => i + 1),
    );
  });

  test('equal scores preserve caller order', () {
    final prompts = [past(3, 8), past(1, 8), past(2, 8)];
    prioritizeRecallPrompts(prompts, now, historyWindow: 10);
    expect(prompts.map((p) => p.cardId), [3, 1, 2]);
  });

  test(
    'four due Past cards lead a ten-card selection and other cards fill it',
    () {
      final prompts = [
        for (var id = 1; id <= 12; id++)
          StudyPrompt(
            card: sample(id, id < 7 ? 0 : 2),
            cue: StudyCue.fromLanguage,
          ),
        for (var id = 13; id <= 16; id++)
          StudyPrompt(card: sample(id, 8), cue: StudyCue.fromLanguage),
        StudyPrompt(
          card: sample(17, 10, due: false),
          cue: StudyCue.fromLanguage,
        ),
      ];
      prioritizeRecallPrompts(prompts, DateTime.now(), historyWindow: 10);
      expect(prompts.length, 17);
      expect(prompts.take(4).map((p) => p.cardId).toSet(), {13, 14, 15, 16});
      expect(prompts.take(10).length, 10);
      expect(
        prompts
            .take(10)
            .where((p) => isPastDue(p, DateTime.now(), historyWindow: 10))
            .length,
        4,
      );
      expect(prompts.map((p) => p.cardId), contains(17));
    },
  );
  test('due priority follows the selected direction', () {
    final prompt = StudyPrompt(card: sample(1, 8), cue: StudyCue.toLanguage);
    expect(isPastDue(prompt, DateTime.now(), historyWindow: 10), isFalse);
  });
}

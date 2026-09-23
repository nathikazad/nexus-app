import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/recall_priority.dart';
import 'study_setup_page_test.dart' show sample;

void main() {
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

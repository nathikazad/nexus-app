import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

bool isPastDue(
  StudyPrompt prompt,
  DateTime now, {
  required int historyWindow,
}) =>
    learningStage(prompt.card, prompt.cue, window: historyWindow) ==
        LearningStage.past &&
    prompt.card.scheduleFor(prompt.cue).isDueAt(now);

/// Prioritize due Past cards without excluding other matching cards.
/// Callers shuffle first so cards with equal priority vary between sessions.
void prioritizeRecallPrompts(
  List<StudyPrompt> prompts,
  DateTime now, {
  required int historyWindow,
}) {
  prompts.sort((a, b) {
    final aDue = isPastDue(a, now, historyWindow: historyWindow);
    final bDue = isPastDue(b, now, historyWindow: historyWindow);
    if (aDue != bDue) return aDue ? -1 : 1;
    final sa = learningStage(a.card, a.cue, window: historyWindow);
    final sb = learningStage(b.card, b.cue, window: historyWindow);
    final byStage = sa.index.compareTo(sb.index);
    if (byStage != 0) return byStage;
    if (sa != LearningStage.past) return 0;
    return recalledAnswers(
      a.card,
      a.cue,
      historyWindow,
    ).compareTo(recalledAnswers(b.card, b.cue, historyWindow));
  });
}

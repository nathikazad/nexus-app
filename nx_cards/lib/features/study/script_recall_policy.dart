import 'package:nx_cards/domain/cards_models.dart';

enum RecallInteraction { standard, scriptDrawing }

abstract final class ScriptRecallPolicy {
  static const allowedCues = <StudyCue>[
    StudyCue.fromLanguage,
    StudyCue.toLanguage,
  ];

  static bool appliesTo(StudyCard card) =>
      card.wordCategory?.trim().toLowerCase() == 'script';

  static RecallInteraction interactionFor(StudyPrompt prompt) =>
      appliesTo(prompt.card) && prompt.cue == StudyCue.fromLanguage
      ? RecallInteraction.scriptDrawing
      : RecallInteraction.standard;
}

import 'package:nx_cards/browser/browser.dart';

enum RecallInteraction { standard, scriptDrawing }

abstract final class ScriptRecallPolicy {
  static const allowedCues = <StudyCue>[
    StudyCue.fromLanguage,
    StudyCue.toLanguage,
  ];

  static bool appliesTo(StudyCard card) => card.isScriptCard;

  static RecallInteraction interactionFor(StudyPrompt prompt) =>
      appliesTo(prompt.card) && prompt.cue == StudyCue.fromLanguage
      ? RecallInteraction.scriptDrawing
      : RecallInteraction.standard;
}

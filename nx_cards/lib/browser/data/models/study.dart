import 'package:nx_cards/browser/data/models/card.dart';
import 'package:nx_cards/browser/data/models/memory.dart';
import 'package:nx_cards/browser/data/models/study_card.dart';

abstract interface class RecallSelection {
  String get storageKey;
  String get label;
}

enum RecallComponent implements RecallSelection {
  meaning,
  sound,
  script;

  @override
  String get storageKey => name;
  @override
  String get label => switch (this) {
    meaning => 'Meaning',
    sound => 'Sound',
    script => 'Script',
  };
}

/// A direction is one independently scheduled question on a single card.
enum StudyCue implements RecallSelection {
  meaningToSound(
    'meaning_to_sound',
    RecallComponent.meaning,
    RecallComponent.sound,
  ),
  meaningToScript(
    'meaning_to_script',
    RecallComponent.meaning,
    RecallComponent.script,
  ),
  soundToMeaning(
    'sound_to_meaning',
    RecallComponent.sound,
    RecallComponent.meaning,
  ),
  soundToScript(
    'sound_to_script',
    RecallComponent.sound,
    RecallComponent.script,
  ),
  scriptToMeaning(
    'script_to_meaning',
    RecallComponent.script,
    RecallComponent.meaning,
  ),
  scriptToSound(
    'script_to_sound',
    RecallComponent.script,
    RecallComponent.sound,
  ),
  frontToBack('front_to_back', null, null),
  backToFront('back_to_front', null, null);

  const StudyCue(this.storageKey, this.source, this.target);
  @override
  final String storageKey;
  final RecallComponent? source;
  final RecallComponent? target;
  bool get involvesScript =>
      source == RecallComponent.script || target == RecallComponent.script;
  bool get isListening => source == RecallComponent.sound;
  @override
  String get label => source != null
      ? '${source!.label} → ${target!.label}'
      : this == frontToBack
      ? 'Front → Back'
      : 'Back → Front';
  static const languageDirections = [
    meaningToSound,
    meaningToScript,
    soundToMeaning,
    soundToScript,
    scriptToMeaning,
    scriptToSound,
  ];
  static const genericDirections = [frontToBack, backToFront];
}

/// Union, not a sum: selecting two components must never duplicate a review.
Set<StudyCue> selectedCues(
  StudyCard card,
  Iterable<RecallComponent> components,
) {
  final selected = components.toSet();
  return {
    for (final cue in card.directions)
      if ((!card.isLanguageCard ||
              selected.contains(cue.source) ||
              selected.contains(cue.target)) &&
          card.studiesCue(cue) &&
          card.scheduleFor(cue).enabled)
        cue,
  };
}

class StudyPrompt {
  const StudyPrompt({
    required this.card,
    required this.cue,
    this.showEnglishAndTransliteration = false,
    this.additionalCues = const {},
  });
  final StudyCard card;
  final StudyCue cue;
  final Set<StudyCue> additionalCues;
  Set<StudyCue> get testedCues => {cue, ...additionalCues};
  final bool showEnglishAndTransliteration;
  bool get isListening => cue.isListening;
  bool get recallsTarget =>
      testedCues.any((c) => c.target == RecallComponent.script);
  int get cardId => card.id;
  String get prompt => switch (cue.source) {
    RecallComponent.meaning => card.front,
    RecallComponent.script => card.back,
    RecallComponent.sound => 'Listen',
    null => cue == StudyCue.frontToBack ? card.front : card.back,
  };
  String get answer => switch (cue.target) {
    RecallComponent.meaning => card.front,
    RecallComponent.script => card.back,
    RecallComponent.sound =>
      (card.content as LanguageCardContent).transliteration,
    null => cue == StudyCue.frontToBack ? card.back : card.front,
  };
  String get instruction => testedCues.length > 1
      ? 'Recall ${testedCues.map((c) => c.target!.label.toLowerCase()).join(' and ')}'
      : switch (cue.target) {
          RecallComponent.meaning => 'Recall the meaning',
          RecallComponent.sound => 'Say the pronunciation',
          RecallComponent.script => 'Recall the script · writing is optional',
          null => 'Recall the answer',
        };
  CardSchedule get schedule => card.scheduleFor(cue);
  List<CardReview> get reviewHistory => card.reviewHistoryFor(cue);
  bool get isNew => schedule.isNew;
  bool isDueAt(DateTime now) => schedule.isDueAt(now);
  StudyPrompt withCard(StudyCard value) => StudyPrompt(
    card: value,
    cue: cue,
    additionalCues: additionalCues,
    showEnglishAndTransliteration: showEnglishAndTransliteration,
  );
}

/// Combine only eligible directions already selected, never add hidden tests.
List<StudyPrompt> combineRecallPrompts(Iterable<StudyPrompt> prompts) {
  final groups = <(int, Object), StudyPrompt>{};
  for (final prompt in prompts) {
    final key = (prompt.cardId, prompt.cue.source ?? prompt.cue);
    final previous = groups[key];
    final cues = {...?previous?.testedCues, ...prompt.testedCues};
    final first = previous ?? prompt;
    groups[key] = StudyPrompt(
      card: first.card,
      cue: first.cue,
      additionalCues: Set.unmodifiable(cues..remove(first.cue)),
      showEnglishAndTransliteration: first.showEnglishAndTransliteration,
    );
  }
  return groups.values.toList();
}

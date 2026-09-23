import 'package:nx_cards/browser/data/models/card.dart';
import 'package:nx_cards/browser/data/models/memory.dart';
import 'package:nx_cards/browser/data/models/study_card.dart';

enum StudyCue {
  fromLanguage('from_language'),
  toLanguage('to_language'),
  transliteration('transliteration');

  const StudyCue(this.storageKey);

  final String storageKey;

  /// Transliteration remains decodable for archived history only.
  static const activeDirections = [fromLanguage, toLanguage];
}

class StudyPrompt {
  const StudyPrompt({
    required this.card,
    required this.cue,
    this.showEnglishAndTransliteration = false,
  });

  final StudyCard card;
  final StudyCue cue;
  final bool showEnglishAndTransliteration;

  int get cardId => card.id;
  String get prompt => switch (cue) {
    StudyCue.fromLanguage =>
      showEnglishAndTransliteration && card.content is LanguageCardContent
          ? '${card.front}\n${(card.content as LanguageCardContent).transliteration}'
          : card.front,
    StudyCue.toLanguage => card.back,
    StudyCue.transliteration => switch (card.content) {
      LanguageCardContent(:final transliteration) => transliteration,
      _ => card.front,
    },
  };
  CardSchedule get schedule => card.scheduleFor(cue);
  List<CardReview> get reviewHistory => card.reviewHistoryFor(cue);
  bool get isNew => schedule.isNew;
  bool isDueAt(DateTime now) => schedule.isDueAt(now);

  StudyPrompt withCard(StudyCard value) => StudyPrompt(
    card: value,
    cue: cue,
    showEnglishAndTransliteration: showEnglishAndTransliteration,
  );
}

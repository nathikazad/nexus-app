import 'package:nx_cards/browser/data/models/card.dart';
import 'package:nx_cards/browser/data/models/memory.dart';
import 'package:nx_cards/browser/data/models/study_card.dart';

enum StudyCue {
  fromLanguage('from_language'),
  toLanguage('to_language'),
  transliteration('transliteration');

  const StudyCue(this.storageKey);

  final String storageKey;
}

class StudyPrompt {
  const StudyPrompt({required this.card, required this.cue});

  final StudyCard card;
  final StudyCue cue;

  int get cardId => card.id;
  String get prompt => switch (cue) {
    StudyCue.fromLanguage => card.front,
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

  StudyPrompt withCard(StudyCard value) => StudyPrompt(card: value, cue: cue);
}

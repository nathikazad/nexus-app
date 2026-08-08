import 'package:nx_cards/domain/card/card_content.dart';
import 'package:nx_cards/domain/card/card_review.dart';
import 'package:nx_cards/domain/card/card_schedule.dart';
import 'package:nx_cards/domain/card/study_card.dart';
import 'package:nx_cards/domain/card/study_cue.dart';

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

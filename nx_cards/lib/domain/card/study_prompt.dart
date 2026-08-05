import 'package:nx_cards/domain/card/card_review.dart';
import 'package:nx_cards/domain/card/card_schedule.dart';
import 'package:nx_cards/domain/card/study_card.dart';
import 'package:nx_cards/domain/card/study_direction.dart';

class StudyPrompt {
  const StudyPrompt({required this.card, required this.direction});

  final StudyCard card;
  final StudyDirection direction;

  int get cardId => card.id;
  String get prompt => switch (direction) {
    StudyDirection.frontToBack => card.front,
    StudyDirection.backToFront => card.back,
  };
  String get answer => switch (direction) {
    StudyDirection.frontToBack => card.back,
    StudyDirection.backToFront => card.front,
  };
  CardSchedule get schedule => card.scheduleFor(direction);
  List<CardReview> get reviewHistory => card.reviewHistoryFor(direction);
  bool get isNew => schedule.isNew;
  bool isDueAt(DateTime now) => schedule.isDueAt(now);

  /// Language supplements describe the stored back side. They are answer
  /// aids in the forward direction, never hints on a reverse prompt.
  bool get showLanguageSupplements => direction == StudyDirection.frontToBack;

  StudyPrompt withCard(StudyCard value) =>
      StudyPrompt(card: value, direction: direction);
}

import 'package:nx_cards/application/ports/clock.dart';
import 'package:nx_cards/domain/card/cards_dashboard.dart';
import 'package:nx_cards/domain/card/study_card.dart';

class StudyQueueService {
  const StudyQueueService(this._clock);

  final Clock _clock;

  List<StudyCard> build(
    CardsDashboard dashboard, {
    int? deckId,
    int newCardLimit = 20,
  }) {
    return dashboard.studyQueue(
      _clock.now(),
      deckId: deckId,
      newCardLimit: newCardLimit,
    );
  }
}

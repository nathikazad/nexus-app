import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/scheduling/scheduling.dart';
import 'package:nx_cards/browser/data/models/collection.dart';
import 'package:nx_cards/browser/data/models/study.dart';

class StudyQueueService {
  const StudyQueueService(this._clock);

  final Clock _clock;

  List<StudyPrompt> build(CardsDashboard dashboard, {int newCardLimit = 20}) {
    return dashboard.studyQueue(_clock.now(), newCardLimit: newCardLimit);
  }
}

final studyQueueServiceProvider = Provider<StudyQueueService>((ref) {
  return StudyQueueService(ref.watch(clockProvider));
});

import 'package:nx_cards/domain/cards_models.dart';

class WordScheduleStatus {
  const WordScheduleStatus({required this.label, required this.isDue});

  final String label;
  final bool isDue;
}

WordScheduleStatus? wordScheduleStatus(StudyCard card, DateTime now) {
  if (card.suspended) {
    return const WordScheduleStatus(label: 'Suspended', isDue: false);
  }

  final schedule = card.scheduleFor(StudyCue.fromLanguage);
  if (!schedule.enabled) return null;

  return WordScheduleStatus(
    label: _stateLabel(schedule),
    isDue: schedule.isDueAt(now),
  );
}

String _stateLabel(CardSchedule schedule) {
  if (schedule.lastReviewedAt == null) return 'New';
  return switch (schedule.schedulingState) {
    'relearning' => 'Relearning',
    'learning' => 'Learning',
    _ => 'Review',
  };
}

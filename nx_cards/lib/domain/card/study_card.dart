import 'package:nx_cards/domain/card/card_review.dart';
import 'package:nx_cards/domain/card/card_schedule.dart';
import 'package:nx_cards/domain/card/card_content.dart';
import 'package:nx_cards/domain/card/study_direction.dart';
import 'package:nx_cards/domain/card/study_prompt.dart';

class StudyCard {
  StudyCard({
    required this.id,
    required this.content,
    required this.deckId,
    required this.deckName,
    required this.tags,
    required Map<StudyDirection, CardSchedule> schedules,
    required Map<StudyDirection, List<CardReview>> reviewHistory,
    required this.suspended,
    this.sourceBookId,
    this.sourceBookName,
    this.updatedAt,
  }) : schedules = Map<StudyDirection, CardSchedule>.unmodifiable(schedules),
       reviewHistory = Map<StudyDirection, List<CardReview>>.unmodifiable({
         for (final entry in reviewHistory.entries)
           entry.key: List<CardReview>.unmodifiable(entry.value),
       });

  final int id;
  final CardContent content;
  String get front => content.front;
  String get back => content.back;
  bool get isLanguageCard => content is LanguageCardContent;
  final int deckId;
  final String deckName;
  final List<String> tags;
  final Map<StudyDirection, CardSchedule> schedules;
  final Map<StudyDirection, List<CardReview>> reviewHistory;
  final bool suspended;
  final int? sourceBookId;
  final String? sourceBookName;

  /// Server update time is deliberately retained for future local/remote
  /// conflict handling.
  final DateTime? updatedAt;

  CardSchedule scheduleFor(StudyDirection direction) =>
      schedules[direction] ?? const CardSchedule.initial(enabled: false);

  List<CardReview> reviewHistoryFor(StudyDirection direction) =>
      reviewHistory[direction] ?? const <CardReview>[];

  Iterable<StudyPrompt> get prompts sync* {
    if (suspended) return;
    for (final direction in StudyDirection.values) {
      if (scheduleFor(direction).enabled) {
        yield StudyPrompt(card: this, direction: direction);
      }
    }
  }

  DateTime? get nextDueAt {
    final dueDates = <DateTime>[
      for (final direction in StudyDirection.values)
        if (scheduleFor(direction).enabled &&
            scheduleFor(direction).dueAt != null)
          scheduleFor(direction).dueAt!,
    ]..sort();
    return dueDates.firstOrNull;
  }

  StudyCard updateDirection({
    required StudyDirection direction,
    required CardSchedule schedule,
    required List<CardReview> history,
  }) {
    return copyWith(
      schedules: <StudyDirection, CardSchedule>{
        ...schedules,
        direction: schedule,
      },
      reviewHistory: <StudyDirection, List<CardReview>>{
        ...reviewHistory,
        direction: history,
      },
    );
  }

  StudyCard copyWith({
    CardContent? content,
    List<String>? tags,
    Map<StudyDirection, CardSchedule>? schedules,
    Map<StudyDirection, List<CardReview>>? reviewHistory,
    bool? suspended,
    DateTime? updatedAt,
  }) {
    return StudyCard(
      id: id,
      content: content ?? this.content,
      deckId: deckId,
      deckName: deckName,
      tags: tags ?? this.tags,
      schedules: schedules ?? this.schedules,
      reviewHistory: reviewHistory ?? this.reviewHistory,
      suspended: suspended ?? this.suspended,
      sourceBookId: sourceBookId,
      sourceBookName: sourceBookName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

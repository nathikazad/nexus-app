import 'package:nx_cards/domain/card/card_review.dart';
import 'package:nx_cards/domain/card/card_schedule.dart';
import 'package:nx_cards/domain/card/card_content.dart';
import 'package:nx_cards/domain/card/learning_status.dart';
import 'package:nx_cards/domain/card/study_cue.dart';
import 'package:nx_cards/domain/card/study_prompt.dart';

class StudyCard {
  StudyCard({
    required this.id,
    required this.content,
    required this.deckId,
    required this.deckName,
    required Map<StudyCue, CardSchedule> schedules,
    required Map<StudyCue, List<CardReview>> reviewHistory,
    required this.suspended,
    this.learningStatus = LearningStatus.notStarted,
    Map<String, List<String>> tags = const <String, List<String>>{},
    this.modelTypeName,
    this.sourceBookId,
    this.sourceBookName,
    this.updatedAt,
  }) : schedules = Map<StudyCue, CardSchedule>.unmodifiable(schedules),
       tags = Map<String, List<String>>.unmodifiable({
         for (final entry in tags.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       reviewHistory = Map<StudyCue, List<CardReview>>.unmodifiable({
         for (final entry in reviewHistory.entries)
           entry.key: List<CardReview>.unmodifiable(entry.value),
       });

  final int id;
  final CardContent content;
  String get front => content.front;
  String get back => content.back;
  bool get isLanguageCard => content is LanguageCardContent;
  bool get isWordCard => modelTypeName == 'Word' || modelTypeName == 'Verb';
  bool get isPhraseCard => modelTypeName == 'Phrase';
  bool get isScriptCard => modelTypeName == 'Script';
  final int deckId;
  final String deckName;
  final Map<StudyCue, CardSchedule> schedules;
  final Map<StudyCue, List<CardReview>> reviewHistory;
  final bool suspended;
  final LearningStatus learningStatus;
  bool get isRecallEligible => learningStatus.isRecallEligible;
  final Map<String, List<String>> tags;
  String? get wordCategory => tags['Word Category']?.firstOrNull;
  String? get studyCategory => isScriptCard
      ? 'Script'
      : isWordCard
      ? wordCategory
      : null;
  final String? modelTypeName;
  final int? sourceBookId;
  final String? sourceBookName;

  /// Server update time is deliberately retained for future local/remote
  /// conflict handling.
  final DateTime? updatedAt;

  CardSchedule scheduleFor(StudyCue cue) =>
      schedules[cue] ?? const CardSchedule.initial(enabled: false);

  List<CardReview> reviewHistoryFor(StudyCue cue) =>
      reviewHistory[cue] ?? const <CardReview>[];

  Iterable<StudyPrompt> get prompts sync* {
    if (suspended) return;
    for (final cue in StudyCue.values) {
      if (scheduleFor(cue).enabled) {
        yield StudyPrompt(card: this, cue: cue);
      }
    }
  }

  DateTime? get nextDueAt {
    final dueDates = <DateTime>[
      for (final cue in StudyCue.values)
        if (scheduleFor(cue).enabled && scheduleFor(cue).dueAt != null)
          scheduleFor(cue).dueAt!,
    ]..sort();
    return dueDates.firstOrNull;
  }

  StudyCard updateCue({
    required StudyCue cue,
    required CardSchedule schedule,
    required List<CardReview> history,
  }) {
    return copyWith(
      schedules: <StudyCue, CardSchedule>{...schedules, cue: schedule},
      reviewHistory: <StudyCue, List<CardReview>>{
        ...reviewHistory,
        cue: history,
      },
    );
  }

  StudyCard copyWith({
    CardContent? content,
    Map<StudyCue, CardSchedule>? schedules,
    Map<StudyCue, List<CardReview>>? reviewHistory,
    bool? suspended,
    LearningStatus? learningStatus,
    DateTime? updatedAt,
  }) {
    return StudyCard(
      id: id,
      content: content ?? this.content,
      deckId: deckId,
      deckName: deckName,
      schedules: schedules ?? this.schedules,
      reviewHistory: reviewHistory ?? this.reviewHistory,
      suspended: suspended ?? this.suspended,
      learningStatus: learningStatus ?? this.learningStatus,
      tags: tags,
      modelTypeName: modelTypeName,
      sourceBookId: sourceBookId,
      sourceBookName: sourceBookName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

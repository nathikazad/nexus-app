import 'package:nx_cards/browser/data/models/card.dart';
import 'package:nx_cards/browser/data/models/memory.dart';
import 'package:nx_cards/browser/data/models/study.dart';

class StudyCard {
  StudyCard({
    required this.id,
    required this.content,
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
  String? get language => tags['Language']?.firstOrNull;
  final Map<StudyCue, CardSchedule> schedules;
  final Map<StudyCue, List<CardReview>> reviewHistory;
  final bool suspended;
  final LearningStatus learningStatus;
  bool get isRecallEligible => learningStatus.isRecallEligible;
  final Map<String, List<String>> tags;
  List<String> get wordCategories => <String>{
    for (final category in tags['Word Category'] ?? const <String>[])
      if (category.trim().isNotEmpty) category.trim(),
    for (final category in tags['Part of Speech'] ?? const <String>[])
      if (category.trim().isNotEmpty) category.trim(),
  }.toList(growable: false);
  String? get wordCategory => wordCategories.firstOrNull;
  List<String> get studyCategories => isScriptCard
      ? const <String>['Script']
      : isPhraseCard
      ? const <String>['Phrase']
      : modelTypeName == 'Verb'
      ? const <String>['Verb']
      : modelTypeName == 'Word'
      ? wordCategories
      : const <String>[];
  String? get studyCategory => studyCategories.firstOrNull;
  bool belongsToStudyCategory(String category) =>
      studyCategories.contains(category);
  String? get progressionCohort {
    final category = studyCategory;
    if (category != null) {
      return language == null ? null : 'language:$language:$category';
    }
    final bookId = sourceBookId;
    return bookId == null ? null : 'book:$bookId';
  }

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

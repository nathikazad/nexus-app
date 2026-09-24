import 'package:nx_cards/browser/data/models/card.dart';
import 'package:nx_cards/browser/data/models/memory.dart';
import 'package:nx_cards/browser/data/models/study.dart';

class StudyCard {
  StudyCard({
    required this.id,
    this.notes,
    required this.content,
    required Map<StudyCue, CardSchedule> schedules,
    required Map<StudyCue, List<CardReview>> reviewHistory,
    required this.suspended,
    this.learningStatus = LearningStatus.notStarted,
    Map<String, List<String>> tags = const <String, List<String>>{},
    List<List<String>>? categoryPaths,
    String? modelTypeName,
    this.sourceBookId,
    this.sourceBookName,
    Set<int> linkedWordIds = const <int>{},
    this.updatedAt,
    this.isSummary = false,
  }) : modelTypeName =
           const {'Word', 'Verb', 'Phrase', 'Script'}.contains(modelTypeName)
           ? 'LanguageFlashcard'
           : modelTypeName,
       categoryPaths = List<List<String>>.unmodifiable([
         for (final path
             in categoryPaths ??
                 legacyCategoryPaths(
                   migrateLanguageTags(tags, modelTypeName)['Category'] ??
                       const [],
                 ))
           List<String>.unmodifiable(path),
       ]),
       schedules = Map<StudyCue, CardSchedule>.unmodifiable(schedules),
       linkedWordIds = Set<int>.unmodifiable(linkedWordIds),
       tags = Map<String, List<String>>.unmodifiable({
         for (final entry in migrateLanguageTags(tags, modelTypeName).entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       reviewHistory = Map<StudyCue, List<CardReview>>.unmodifiable({
         for (final entry in reviewHistory.entries)
           entry.key: List<CardReview>.unmodifiable(entry.value),
       });

  /// Library projections must be hydrated before editing or reviewing.
  final bool isSummary;
  final int id;
  final String? notes;
  final CardContent content;
  String get front => content.front;
  String get back => content.back;
  bool get isLanguageCard => content is LanguageCardContent;
  bool get isPhraseCard => hasCategory('Phrase');
  bool get isScriptCard => hasCategory('Script');
  bool get isWordCard => isLanguageCard && hasCategory('Word');
  final List<List<String>> categoryPaths;
  bool hasCategoryPath(List<String> prefix) => categoryPaths.any(
    (path) =>
        path.length >= prefix.length &&
        Iterable<int>.generate(
          prefix.length,
        ).every((i) => path[i] == prefix[i]),
  );
  bool hasCategory(String name) =>
      categoryPaths.any((path) => path.contains(name));
  String? get language => tags['Language']?.firstOrNull;
  final Map<StudyCue, CardSchedule> schedules;
  final Map<StudyCue, List<CardReview>> reviewHistory;
  final bool suspended;
  final LearningStatus learningStatus;
  bool get active => learningStatus.isRecallEligible;
  bool get isRecallEligible => active;
  final Map<String, List<String>> tags;
  List<String> get categories => _tagValues('Category');
  List<String> get collections => _tagValues('Collection');
  List<String> _tagValues(String system) => <String>{
    for (final value in tags[system] ?? const <String>[])
      if (value.trim().isNotEmpty) value.trim(),
  }.toList(growable: false);

  final String? modelTypeName;
  final int? sourceBookId;
  final String? sourceBookName;
  final Set<int> linkedWordIds;

  /// Server update time is deliberately retained for future local/remote
  /// conflict handling.
  final DateTime? updatedAt;

  CardSchedule scheduleFor(StudyCue cue) =>
      schedules[cue] ?? const CardSchedule.initial(enabled: false);

  List<CardReview> reviewHistoryFor(StudyCue cue) =>
      reviewHistory[cue] ?? const <CardReview>[];

  Iterable<StudyPrompt> get prompts sync* {
    if (suspended) return;
    for (final cue in StudyCue.activeDirections) {
      if (scheduleFor(cue).enabled) {
        yield StudyPrompt(card: this, cue: cue);
      }
    }
  }

  DateTime? get nextDueAt {
    final dueDates = <DateTime>[
      for (final cue in StudyCue.activeDirections)
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
    Set<int>? linkedWordIds,
    DateTime? updatedAt,
    bool? isSummary,
  }) {
    return StudyCard(
      id: id,
      notes: notes,
      isSummary: isSummary ?? this.isSummary,
      content: content ?? this.content,
      schedules: schedules ?? this.schedules,
      reviewHistory: reviewHistory ?? this.reviewHistory,
      suspended: suspended ?? this.suspended,
      learningStatus: learningStatus ?? this.learningStatus,
      tags: tags,
      categoryPaths: categoryPaths,
      modelTypeName: modelTypeName,
      sourceBookId: sourceBookId,
      sourceBookName: sourceBookName,
      linkedWordIds: linkedWordIds ?? this.linkedWordIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Decode pre-migration offline snapshots once into the canonical tag shape.
/// Browsing and scheduling never infer categories from the resulting type.
Map<String, List<String>> migrateLanguageTags(
  Map<String, List<String>> tags,
  String? legacyType,
) {
  final categories = <String>{
    ...tags['Category'] ?? const [],
    ...tags['Word Category'] ?? const [],
    ...tags['Part of Speech'] ?? const [],
    ...tags['Study Category'] ?? const [],
    if (const {'Verb', 'Phrase', 'Script'}.contains(legacyType)) legacyType!,
  };
  if (legacyType == 'Word' && categories.isEmpty) categories.add('Word');
  return {
    for (final entry in tags.entries)
      if (!const {
        'Word Category',
        'Part of Speech',
        'Study Category',
        'Category',
      }.contains(entry.key))
        entry.key: entry.value,
    if (categories.isNotEmpty) 'Category': categories.toList(),
  };
}

/// Compatibility for cached cards received before hierarchical tag paths.
/// New server paths are authoritative, including user-created subcategories.
List<List<String>> legacyCategoryPaths(Iterable<String> categories) => [
  for (final name in categories)
    if (const {
      'Noun',
      'Verb',
      'Adjective',
      'Adverb',
      'Pronoun',
      'Preposition',
      'Postposition',
      'Conjunction',
      'Numeral',
      'Classifier',
      'Particle',
      'Suffix',
      'Other',
    }.contains(name))
      ['Word', name]
    else
      [name],
];

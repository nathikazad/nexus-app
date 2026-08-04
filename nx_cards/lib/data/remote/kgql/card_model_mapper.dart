import 'dart:convert';

import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_db/kgql.dart';

const _legacyLastReviewedAt = 'last_reviewed_at';
const _legacyStability = 'stability';
const _legacyDifficulty = 'difficulty';
const _legacySchedulingState = 'scheduling_state';
const _legacyLearningStep = 'learning_step';
const _legacyReviewCount = 'review_count';
const _legacyLapseCount = 'lapse_count';

CardDeck cardDeckFromModel(Model model) {
  final languages = model.tags?[deckLanguageTagSystem] ?? const <String>[];
  return CardDeck(
    id: model.id,
    name: model.name,
    description: model.description?.trim() ?? '',
    language: languages.firstOrNull,
    archived: model.attrBool(attrArchived) ?? false,
    updatedAt: DateTime.tryParse(model.updatedAt ?? '')?.toUtc(),
  );
}

StudyCard? studyCardFromModel(Model model) {
  final deck = _relatedModels(model, deckModelType).firstOrNull;
  if (deck == null) return null;
  final book = _relatedModels(model, bookModelType).firstOrNull;
  final schedule = _jsonMap(model.attributes?[attrSchedule]);
  final history = _reviewHistoryFrom(model.attributes?[attrReviewHistory]);
  return StudyCard(
    id: model.id,
    content: model.modelType?.name == languageCardModelType
        ? LanguageCardContent(
            english: model.name,
            originalScript: model.description?.trim() ?? '',
            transliteration:
                model.attrString(attrTransliteration)?.trim() ?? '',
            audioUrl: model.attrString(attrAudioUrl)?.trim(),
          )
        : BasicCardContent(
            front: model.name,
            back: model.description?.trim() ?? '',
          ),
    deckId: deck.id,
    deckName: deck.name,
    tags: model.tags?[cardTagsTagSystem] ?? const <String>[],
    dueAt: model.attrDateTime(attrDueAt)?.toUtc(),
    lastReviewedAt:
        _dateTimeFrom(schedule['last_reviewed_at']) ??
        model.attrDateTime(_legacyLastReviewedAt)?.toUtc(),
    stability:
        _doubleFrom(schedule['stability']) ??
        model.attrDouble(_legacyStability),
    difficulty:
        _doubleFrom(schedule['difficulty']) ??
        model.attrDouble(_legacyDifficulty),
    schedulingState:
        schedule['state']?.toString() ??
        model.attrString(_legacySchedulingState) ??
        'learning',
    learningStep:
        _intFrom(schedule['step']) ?? model.attrInt(_legacyLearningStep),
    suspended: model.attrBool(attrSuspended) ?? false,
    reviewCount:
        _intFrom(schedule['review_count']) ??
        model.attrInt(_legacyReviewCount) ??
        history.length,
    lapseCount:
        _intFrom(schedule['lapse_count']) ??
        model.attrInt(_legacyLapseCount) ??
        0,
    reviewHistory: history,
    sourceBookId: book?.id,
    sourceBookName: book?.name,
    updatedAt: DateTime.tryParse(model.updatedAt ?? '')?.toUtc(),
  );
}

List<_RelatedModel> _relatedModels(Model model, String modelType) {
  final nested = model.relations?[modelType];
  if (nested != null) {
    return <_RelatedModel>[
      for (final value in nested) _RelatedModel(value.id, value.name),
    ];
  }
  return <_RelatedModel>[
    for (final relation in model.relationsList ?? const <Relation>[])
      if (relation.modelType == modelType)
        _RelatedModel(relation.modelId, relation.name ?? ''),
  ];
}

final class _RelatedModel {
  const _RelatedModel(this.id, this.name);

  final int id;
  final String name;
}

Map<String, dynamic> emptyScheduleJson() => const <String, dynamic>{
  'version': 1,
  'algorithm': 'fsrs',
  'state': 'learning',
  'step': 0,
  'last_reviewed_at': null,
  'stability': null,
  'difficulty': null,
  'review_count': 0,
  'lapse_count': 0,
};

Map<String, dynamic> scheduleJson(StudyCard card) => <String, dynamic>{
  'version': 1,
  'algorithm': 'fsrs',
  'state': card.schedulingState,
  'step': card.learningStep,
  'last_reviewed_at': card.lastReviewedAt?.toUtc().toIso8601String(),
  'stability': card.stability,
  'difficulty': card.difficulty,
  'review_count': card.reviewCount,
  'lapse_count': card.lapseCount,
};

Map<String, dynamic> reviewHistoryJson(List<CardReview> reviews) =>
    <String, dynamic>{
      'version': 1,
      'items': reviews.map((review) => review.toJson()).toList(),
    };

List<CardReview> _reviewHistoryFrom(Object? raw) {
  final items = _jsonMap(raw)['items'];
  if (items is! List) return const <CardReview>[];
  return items.map(CardReview.fromJson).whereType<CardReview>().toList();
}

Map<String, dynamic> _jsonMap(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return const <String, dynamic>{};
    }
  }
  return const <String, dynamic>{};
}

DateTime? _dateTimeFrom(Object? raw) =>
    DateTime.tryParse(raw?.toString() ?? '')?.toUtc();

int? _intFrom(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '');
}

double? _doubleFrom(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}

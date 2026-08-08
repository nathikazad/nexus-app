import 'dart:convert';

import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_db/kgql.dart';

CardDeck cardDeckFromModel(Model model) {
  return CardDeck(
    id: model.id,
    name: model.name,
    description: model.description?.trim() ?? '',
    fromLanguage: model.attributes?[attrFromLanguage]
        ?.toString()
        .trim()
        .nullIfEmpty,
    toLanguage: model.attributes?[attrToLanguage]
        ?.toString()
        .trim()
        .nullIfEmpty,
    archived: model.attrBool(attrArchived) ?? false,
    updatedAt: DateTime.tryParse(model.updatedAt ?? '')?.toUtc(),
  );
}

StudyCard? studyCardFromModel(Model model) {
  final deck = _relatedModels(model, deckModelType).firstOrNull;
  if (deck == null) return null;
  final book = _relatedModels(model, bookModelType).firstOrNull;
  final schedule = _jsonMap(model.attributes?[attrSchedule]);
  final history = _reviewHistoryByCueFrom(model.attributes?[attrReviewHistory]);
  final cardDetails = _jsonMap(model.attributes?[attrCardDetails]);
  final front = cardDetails['front']?.toString().trim() ?? '';
  final back = cardDetails['back']?.toString().trim() ?? '';
  final languageDetails = _jsonMap(model.attributes?[attrLanguageDetails]);
  return StudyCard(
    id: model.id,
    content: model.modelType?.name == languageCardModelType
        ? LanguageCardContent(
            english: front,
            originalScript: back,
            transliteration:
                languageDetails['transliteration']?.toString().trim() ?? '',
            audioUrl: languageDetails['audio_url']?.toString().trim(),
            examples: languageExamplesFromJson(languageDetails['examples']),
          )
        : BasicCardContent(front: front, back: back),
    deckId: deck.id,
    deckName: deck.name,
    tags: model.tags?[cardTagsTagSystem] ?? const <String>[],
    schedules: <StudyCue, CardSchedule>{
      for (final cue in StudyCue.values)
        cue: _scheduleFrom(_jsonMap(schedule['cues'])[cue.storageKey]),
    },
    reviewHistory: history,
    suspended: model.attrBool(attrSuspended) ?? false,
    sourceBookId: book?.id,
    sourceBookName: book?.name,
    updatedAt: DateTime.tryParse(model.updatedAt ?? '')?.toUtc(),
  );
}

Map<String, Object?> cardDetailsJson(CardContent content) => <String, Object?>{
  'front': content.front,
  'back': content.back,
};

Map<String, Object?> languageDetailsJson(LanguageCardContent content) =>
    <String, Object?>{
      'transliteration': content.transliteration,
      'audio_url': content.audioUrl,
      'examples': content.examples.map((example) => example.toJson()).toList(),
    };

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

List<LanguageExample> languageExamplesFromJson(Object? raw) {
  if (raw is! List) return const <LanguageExample>[];
  return <LanguageExample>[
    for (final value in raw)
      if (value is Map)
        LanguageExample.fromJson(Map<String, dynamic>.from(value)),
  ];
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

Map<String, dynamic> emptyScheduleJson({required bool languageCard}) =>
    <String, dynamic>{
      'version': 3,
      'algorithm': 'fsrs',
      'cues': <String, Object?>{
        for (final cue in StudyCue.values)
          cue.storageKey: _scheduleNodeJson(
            CardSchedule.initial(
              enabled: cue == StudyCue.fromLanguage || languageCard,
            ),
          ),
      },
    };

Map<String, dynamic> scheduleJson(StudyCard card) => <String, dynamic>{
  'version': 3,
  'algorithm': 'fsrs',
  'cues': <String, Object?>{
    for (final cue in StudyCue.values)
      cue.storageKey: _scheduleNodeJson(card.scheduleFor(cue)),
  },
};

Map<String, dynamic> emptyReviewHistoryJson() => <String, dynamic>{
  'version': 3,
  'items': <Object?>[],
};

Map<String, dynamic> reviewHistoryJson(StudyCard card) => <String, dynamic>{
  'version': 3,
  'items': _reviewHistoryItems(card),
};

List<Map<String, Object?>> _reviewHistoryItems(StudyCard card) {
  final items = <Map<String, Object?>>[
    for (final cue in StudyCue.values)
      for (final review in card.reviewHistoryFor(cue))
        <String, Object?>{'cue': cue.storageKey, ...review.toJson()},
  ];
  items.sort(
    (left, right) => left['reviewed_at'].toString().compareTo(
      right['reviewed_at'].toString(),
    ),
  );
  return items;
}

Map<StudyCue, List<CardReview>> _reviewHistoryByCueFrom(Object? raw) {
  final root = _jsonMap(raw);
  final items = root['items'];
  return <StudyCue, List<CardReview>>{
    for (final cue in StudyCue.values)
      cue: items is List
          ? items
                .whereType<Map>()
                .where((item) => item['cue'] == cue.storageKey)
                .map(
                  (item) =>
                      CardReview.fromJson(Map<String, dynamic>.from(item)),
                )
                .whereType<CardReview>()
                .toList()
          : const <CardReview>[],
  };
}

CardSchedule _scheduleFrom(Object? raw) {
  final json = _jsonMap(raw);
  return CardSchedule(
    enabled: json['enabled'] == true,
    dueAt: _dateTimeFrom(json['due_at']),
    lastReviewedAt: _dateTimeFrom(json['last_reviewed_at']),
    stability: _doubleFrom(json['stability']),
    difficulty: _doubleFrom(json['difficulty']),
    schedulingState: json['state']?.toString() ?? 'learning',
    learningStep: _intFrom(json['step']),
    reviewCount: _intFrom(json['review_count']) ?? 0,
    lapseCount: _intFrom(json['lapse_count']) ?? 0,
  );
}

Map<String, Object?> _scheduleNodeJson(CardSchedule schedule) =>
    <String, Object?>{
      'enabled': schedule.enabled,
      'state': schedule.schedulingState,
      'step': schedule.learningStep,
      'due_at': schedule.dueAt?.toUtc().toIso8601String(),
      'last_reviewed_at': schedule.lastReviewedAt?.toUtc().toIso8601String(),
      'stability': schedule.stability,
      'difficulty': schedule.difficulty,
      'review_count': schedule.reviewCount,
      'lapse_count': schedule.lapseCount,
    };

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

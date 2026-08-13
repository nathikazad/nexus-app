import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:nx_cards/data/local/drift/cards_database.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/data/remote/kgql/card_model_mapper.dart';
import 'package:nx_cards/domain/cards_models.dart';

final class DriftCardsMapper {
  const DriftCardsMapper();

  LocalCardDecksCompanion deckToCompanion(
    CardDeck deck, {
    required String accountKey,
    required String? serverHash,
  }) {
    return LocalCardDecksCompanion.insert(
      accountKey: accountKey,
      remoteId: deck.id,
      name: deck.name,
      description: deck.description,
      fromLanguage: Value(deck.fromLanguage),
      toLanguage: Value(deck.toLanguage),
      archived: deck.archived,
      updatedAt: Value(deck.updatedAt),
      serverHash: Value(serverHash),
    );
  }

  CardDeck deckFromRow(LocalCardDeckRow row) => CardDeck(
    id: row.remoteId,
    name: row.name,
    description: row.description,
    fromLanguage: row.fromLanguage,
    toLanguage: row.toLanguage,
    archived: row.archived,
    updatedAt: row.updatedAt?.toUtc(),
  );

  LocalStudyCardsCompanion cardToCompanion(
    StudyCard card, {
    required String accountKey,
    required CardLocalSyncState syncState,
    bool deletedLocally = false,
  }) {
    final content = card.content;
    return LocalStudyCardsCompanion.insert(
      accountKey: accountKey,
      remoteId: card.id,
      deckId: card.deckId,
      modelType:
          card.modelTypeName ??
          (content is LanguageCardContent ? wordCardModelType : cardModelType),
      front: card.front,
      back: card.back,
      transliteration: Value(
        content is LanguageCardContent ? content.transliteration : null,
      ),
      audioUrl: Value(content is LanguageCardContent ? content.audioUrl : null),
      examplesJson: Value(
        jsonEncode(
          content is LanguageCardContent
              ? content.examples.map((example) => example.toJson()).toList()
              : const <Object?>[],
        ),
      ),
      tagsJson: jsonEncode(card.tags),
      learningStatus: Value(card.learningStatus.storageValue),
      dueAt: Value(card.nextDueAt),
      scheduleJson: jsonEncode(scheduleJson(card)),
      reviewHistoryJson: jsonEncode(reviewHistoryJson(card)),
      suspended: card.suspended,
      sourceBookId: Value(card.sourceBookId),
      sourceBookName: Value(card.sourceBookName),
      updatedAt: Value(card.updatedAt),
      syncState: syncState.name,
      deletedLocally: Value(deletedLocally),
    );
  }

  StudyCard cardFromRow(LocalStudyCardRow row, [CardDeck? deck]) {
    final schedule = _jsonMap(row.scheduleJson);
    final history = _jsonMap(row.reviewHistoryJson);
    return StudyCard(
      id: row.remoteId,
      content: isLanguageCardModelType(row.modelType)
          ? LanguageCardContent(
              english: row.front,
              originalScript: row.back,
              transliteration: row.transliteration ?? '',
              audioUrl: row.audioUrl,
              examples: languageExamplesFromJson(jsonDecode(row.examplesJson)),
            )
          : BasicCardContent(front: row.front, back: row.back),
      deckId: row.deckId,
      deckName: deck?.name ?? unassignedDeckName,
      schedules: <StudyCue, CardSchedule>{
        for (final cue in StudyCue.values)
          cue: _scheduleFrom(_cueNode(schedule, cue)),
      },
      reviewHistory: <StudyCue, List<CardReview>>{
        for (final cue in StudyCue.values) cue: _historyForCue(history, cue),
      },
      suspended: row.suspended,
      learningStatus: LearningStatus.fromStorage(row.learningStatus),
      tags: _tagsMap(row.tagsJson),
      modelTypeName: row.modelType,
      sourceBookId: row.sourceBookId,
      sourceBookName: row.sourceBookName,
      updatedAt: row.updatedAt?.toUtc(),
    );
  }
}

Object? _cueNode(Map<String, dynamic> schedule, StudyCue cue) {
  final cues = schedule['cues'];
  return cues is Map ? cues[cue.storageKey] : null;
}

List<CardReview> _historyForCue(Map<String, dynamic> history, StudyCue cue) {
  final items = history['items'];
  if (items is! List) return const <CardReview>[];
  return items
      .whereType<Map>()
      .where((item) => item['cue'] == cue.storageKey)
      .map((item) => CardReview.fromJson(Map<String, dynamic>.from(item)))
      .whereType<CardReview>()
      .toList();
}

CardSchedule _scheduleFrom(Object? raw) {
  final json = raw is Map
      ? Map<String, dynamic>.from(raw)
      : const <String, dynamic>{};
  return CardSchedule(
    enabled: json['enabled'] == true,
    dueAt: _dateTime(json['due_at']),
    lastReviewedAt: _dateTime(json['last_reviewed_at']),
    stability: _double(json['stability']),
    difficulty: _double(json['difficulty']),
    schedulingState: json['state']?.toString() ?? 'learning',
    learningStep: _int(json['step']),
    reviewCount: _int(json['review_count']) ?? 0,
    lapseCount: _int(json['lapse_count']) ?? 0,
  );
}

Map<String, dynamic> _jsonMap(String raw) {
  final value = jsonDecode(raw);
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

Map<String, List<String>> _tagsMap(String raw) {
  final value = jsonDecode(raw);
  if (value is! Map) return const <String, List<String>>{};
  return <String, List<String>>{
    for (final entry in value.entries)
      if (entry.value is List)
        entry.key.toString(): <String>[
          for (final node in entry.value as List) node.toString(),
        ],
  };
}

DateTime? _dateTime(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toUtc();

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

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
      language: Value(deck.language),
      archived: deck.archived,
      updatedAt: Value(deck.updatedAt),
      serverHash: Value(serverHash),
    );
  }

  CardDeck deckFromRow(LocalCardDeckRow row) => CardDeck(
    id: row.remoteId,
    name: row.name,
    description: row.description,
    language: row.language,
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
      modelType: content is LanguageCardContent
          ? languageCardModelType
          : cardModelType,
      front: card.front,
      back: card.back,
      transliteration: Value(
        content is LanguageCardContent ? content.transliteration : null,
      ),
      audioUrl: Value(content is LanguageCardContent ? content.audioUrl : null),
      tagsJson: jsonEncode(card.tags),
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

  StudyCard cardFromRow(LocalStudyCardRow row, CardDeck deck) {
    final schedule = _jsonMap(row.scheduleJson);
    final history = _jsonMap(row.reviewHistoryJson);
    return StudyCard(
      id: row.remoteId,
      content: row.modelType == languageCardModelType
          ? LanguageCardContent(
              english: row.front,
              originalScript: row.back,
              transliteration: row.transliteration ?? '',
              audioUrl: row.audioUrl,
            )
          : BasicCardContent(front: row.front, back: row.back),
      deckId: row.deckId,
      deckName: deck.name,
      tags: <String>[
        for (final value in _jsonList(row.tagsJson)) value.toString(),
      ],
      schedules: <StudyDirection, CardSchedule>{
        for (final direction in StudyDirection.values)
          direction: _scheduleFrom(schedule[direction.storageKey]),
      },
      reviewHistory: <StudyDirection, List<CardReview>>{
        for (final direction in StudyDirection.values)
          direction: _historyFrom(history[direction.storageKey]),
      },
      suspended: row.suspended,
      sourceBookId: row.sourceBookId,
      sourceBookName: row.sourceBookName,
      updatedAt: row.updatedAt?.toUtc(),
    );
  }
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

List<CardReview> _historyFrom(Object? raw) {
  if (raw is! Map) return const <CardReview>[];
  final items = raw['items'];
  if (items is! List) return const <CardReview>[];
  return items.map(CardReview.fromJson).whereType<CardReview>().toList();
}

Map<String, dynamic> _jsonMap(String raw) {
  final value = jsonDecode(raw);
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

List<dynamic> _jsonList(String raw) {
  final value = jsonDecode(raw);
  return value is List ? value : <dynamic>[];
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

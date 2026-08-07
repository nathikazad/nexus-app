import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/application/ports/cards_sync_transport.dart';
import 'package:nx_cards/data/remote/kgql/card_model_mapper.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_db/cards.dart' as cards_api;
import 'package:nx_db/kgql.dart';

final class KgqlCardsSyncTransport implements CardsSyncTransport {
  const KgqlCardsSyncTransport(this._client);

  final GraphQLClient _client;

  @override
  Future<CardMutationResult> mutateCard(
    StudyCard card, {
    required DateTime clientUpdatedAt,
  }) {
    final content = card.content;
    return _mutate(
      SetModelRequest(
        id: card.id,
        name: card.front,
        attributes: <SetModelAttribute>[
          SetModelAttribute(
            key: attrCardDetails,
            value: cardDetailsJson(content),
          ),
          SetModelAttribute(
            key: attrDueAt,
            value: card.nextDueAt?.toUtc().toIso8601String(),
            delete: card.nextDueAt == null,
          ),
          SetModelAttribute(key: attrSuspended, value: card.suspended),
          SetModelAttribute(key: attrSchedule, value: scheduleJson(card)),
          SetModelAttribute(
            key: attrReviewHistory,
            value: reviewHistoryJson(card),
          ),
          if (content case final LanguageCardContent languageContent)
            SetModelAttribute(
              key: attrLanguageDetails,
              value: languageDetailsJson(languageContent),
            ),
        ],
        tags: <SetModelTag>[
          SetModelTag(system: cardTagsTagSystem, nodes: card.tags, clear: true),
        ],
      ),
      clientUpdatedAt,
    );
  }

  @override
  Future<CardMutationResult> deleteCard(
    int cardId, {
    required DateTime clientUpdatedAt,
  }) => _mutate(SetModelRequest(id: cardId, delete: true), clientUpdatedAt);

  @override
  Future<CardMutationResult> createDeck({
    required String name,
    required String description,
    String? language,
    required DateTime clientUpdatedAt,
  }) => _mutate(
    SetModelRequest(
      modelType: deckModelType,
      name: name,
      description: description,
      attributes: <SetModelAttribute>[
        SetModelAttribute(key: attrArchived, value: false),
      ],
      tags: language == null
          ? null
          : <SetModelTag>[
              SetModelTag(
                system: deckLanguageTagSystem,
                nodes: <String>[language],
                clear: true,
              ),
            ],
    ),
    clientUpdatedAt,
  );

  @override
  Future<CardMutationResult> createCard({
    required CardContent content,
    required int deckId,
    required List<String> tags,
    int? sourceBookId,
    required DateTime clientUpdatedAt,
  }) => _mutate(
    SetModelRequest(
      modelType: content is LanguageCardContent
          ? languageCardModelType
          : cardModelType,
      name: content.front,
      attributes: <SetModelAttribute>[
        SetModelAttribute(
          key: attrCardDetails,
          value: cardDetailsJson(content),
        ),
        SetModelAttribute(key: attrSuspended, value: false),
        SetModelAttribute(
          key: attrSchedule,
          value: emptyScheduleJson(
            enableBackToFront: content is LanguageCardContent,
          ),
        ),
        SetModelAttribute(
          key: attrReviewHistory,
          value: emptyReviewHistoryJson(),
        ),
        if (content case final LanguageCardContent languageContent)
          SetModelAttribute(
            key: attrLanguageDetails,
            value: languageDetailsJson(languageContent),
          ),
      ],
      relations: <ModelRelation>[
        ModelRelation(modelType: deckModelType, link: <int>[deckId]),
        if (sourceBookId != null)
          ModelRelation(modelType: bookModelType, link: <int>[sourceBookId]),
      ],
      tags: <SetModelTag>[
        SetModelTag(system: cardTagsTagSystem, nodes: tags, clear: true),
      ],
    ),
    clientUpdatedAt,
  );

  Future<CardMutationResult> _mutate(
    SetModelRequest request,
    DateTime clientUpdatedAt,
  ) async {
    final result = await cards_api.mutateCardLibrary(
      _client,
      request,
      clientUpdatedAt: clientUpdatedAt,
    );
    return CardMutationResult(
      status: CardMutationStatus.values.byName(result.status.name),
      entityId: result.entityId,
      updatedAt: result.updatedAt,
      deckHashes: <DeckHashRevision>[
        for (final value in result.deckHashes)
          DeckHashRevision(deckId: value.deckId, serverHash: value.syncHash),
      ],
      deletedDeckIds: result.deletedDeckIds,
    );
  }

  @override
  Future<CardDeckSyncBundle> syncDecks({
    required List<CardDeckManifestEntry> manifest,
    Set<int>? deckIds,
  }) async {
    final response = await cards_api.syncCardDecks(
      _client,
      manifest: <Map<String, Object?>>[
        for (final entry in manifest) entry.toJson(),
      ],
      deckIds: deckIds,
    );
    return CardDeckSyncBundle(
      decks: <RemoteCardDeck>[
        for (final entry in response.decks) _remoteDeck(entry),
      ],
      deletedDeckIds: response.deletedIds,
    );
  }

  RemoteCardDeck _remoteDeck(cards_api.CardDeckSyncEntry entry) {
    final rawDeck = entry.bundle['deck'];
    final rawCards = entry.bundle['cards'];
    if (rawDeck is! Map || rawCards is! List) {
      throw StateError('Invalid Card deck bundle: ${entry.bundle}');
    }
    final deck = cardDeckFromModel(
      Model.fromJson(Map<String, dynamic>.from(rawDeck)),
    );
    final cards = <StudyCard>[];
    for (final raw in rawCards) {
      if (raw is! Map) continue;
      final card = studyCardFromModel(
        Model.fromJson(Map<String, dynamic>.from(raw)),
      );
      if (card != null) cards.add(card);
    }
    return RemoteCardDeck(deck: deck, cards: cards, serverHash: entry.syncHash);
  }
}

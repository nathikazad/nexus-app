import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/sync/remote/cards_sync_transport.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_mapper.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_schema.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_api.dart';
import 'package:nx_cards/browser/browser.dart';
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
          SetModelAttribute(
            key: attrLearningStatus,
            value: card.learningStatus.storageValue,
          ),
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
  Future<CardMutationResult> createCard({
    required CardContent content,
    int? sourceBookId,
    required DateTime clientUpdatedAt,
  }) => _mutate(
    SetModelRequest(
      modelType: content is LanguageCardContent
          ? wordCardModelType
          : cardModelType,
      name: content.front,
      attributes: <SetModelAttribute>[
        SetModelAttribute(
          key: attrCardDetails,
          value: cardDetailsJson(content),
        ),
        SetModelAttribute(key: attrSuspended, value: false),
        SetModelAttribute(
          key: attrLearningStatus,
          value: LearningStatus.notStarted.storageValue,
        ),
        SetModelAttribute(
          key: attrSchedule,
          value: emptyScheduleJson(
            languageCard: content is LanguageCardContent,
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
        if (sourceBookId != null)
          ModelRelation(modelType: bookModelType, link: <int>[sourceBookId]),
      ],
    ),
    clientUpdatedAt,
  );

  @override
  Future<List<StudyCard>> syncCards() => fetchKgqlCards(_client);

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
    );
  }
}

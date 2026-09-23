import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/sync/remote/cards_sync_transport.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_mapper.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_schema.dart';
import 'dart:convert';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_db/cards.dart' as cards_api;
import 'package:nx_db/kgql.dart';
import 'package:nx_db/app_sync.dart';

final class KgqlCardsSyncTransport
    implements CardsSyncTransport, HashCardsSyncTransport {
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
          SetModelAttribute(key: attrActive, value: card.active),
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
          ? languageCardModelType
          : cardModelType,
      name: content.front,
      attributes: <SetModelAttribute>[
        SetModelAttribute(
          key: attrCardDetails,
          value: cardDetailsJson(content),
        ),
        SetModelAttribute(key: attrSuspended, value: false),
        SetModelAttribute(key: attrActive, value: false),
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
  Future<List<StudyCard>> syncCards() async =>
      (await _sync()).cards.map((entry) => entry.card).toList();

  @override
  Future<CardHashBundle> cardManifest() => _sync(manifestOnly: true);

  @override
  Future<CardHashBundle> downloadCards(Set<int> ids) => _sync(ids: ids);

  Future<CardHashBundle> _sync({
    Set<int>? ids,
    bool manifestOnly = false,
  }) async {
    if (appStateSyncEnabled) {
      final session = AppSyncClient.forOwner(this, _client, 'cards').session;
      final remote = await session.manifest();
      if (remote != null) {
        final entries = remote.entries;
        final wanted = ids ?? entries.map((e) => e['id'] as int).toSet();
        final items = manifestOnly
            ? <Map<String, dynamic>>[]
            : await session.download(remote, wanted);
        final cards = <HashedCard>[];
        for (final entry in items) {
          final card = studyCardFromModel(
            Model.fromJson(Map<String, dynamic>.from(entry['payload'] as Map)),
          );
          if (card == null || card.id != entry['id']) {
            throw StateError('Invalid card payload');
          }
          cards.add(HashedCard(card, entry['hash'] as String));
        }
        final remoteIds = entries.map((e) => e['id']).toSet();
        return CardHashBundle(
          [
            for (final entry in entries)
              CardHash(entry['id'] as int, entry['hash'] as String),
          ],
          cards,
          {
            for (final id in ids ?? <int>{})
              if (!remoteIds.contains(id)) id,
          },
        );
      }
    }
    final response = await _client.query(
      QueryOptions(
        document: gql(
          r'''query CardHashSync($ids: [Int!], $manifestOnly: Boolean!) {
        syncCards(cardIds: $ids, manifestOnly: $manifestOnly)
      }''',
        ),
        variables: {'ids': ids?.toList(), 'manifestOnly': manifestOnly},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );
    if (response.hasException) throw response.exception!;
    final raw = response.data?['syncCards'];
    final data =
        (raw is String ? jsonDecode(raw) : raw) as Map<String, dynamic>;
    final manifest = [
      for (final entry in data['manifest'] as List)
        CardHash(entry['id'] as int, entry['hash'] as String),
    ];
    final cards = <HashedCard>[];
    for (final entry in data['cards'] as List) {
      final card = studyCardFromModel(
        Model.fromJson(Map<String, dynamic>.from(entry['card'] as Map)),
      );
      if (card == null || card.id != entry['id']) {
        throw StateError('Invalid card payload');
      }
      cards.add(HashedCard(card, entry['hash'] as String));
    }
    return CardHashBundle(
      manifest,
      cards,
      (data['deleted_ids'] as List).cast<int>().toSet(),
    );
  }

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

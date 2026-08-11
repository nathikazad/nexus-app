import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/data/remote/kgql/card_model_mapper.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_db/kgql.dart';

const _baseCardStruct = <String, dynamic>{
  'id': true,
  'name': true,
  'description': true,
  'updated_at': true,
  attrDueAt: true,
  attrSuspended: true,
  attrSchedule: true,
  attrReviewHistory: true,
  attrCardDetails: true,
  'tags': true,
  'model_type': {'id': true, 'name': true},
  deckModelType: {'id': true, 'name': true},
  bookModelType: {'id': true, 'name': true},
};

const _languageCardStruct = <String, dynamic>{
  ..._baseCardStruct,
  attrLanguageDetails: true,
  'relations': {
    'relation_id': true,
    'model_id': true,
    'model_type': true,
    'name': true,
    'relation_name': true,
  },
};

const _wordCardStruct = <String, dynamic>{
  ..._languageCardStruct,
  attrLearningStatus: true,
};

class KgqlCardsRepository implements CardsRepository {
  KgqlCardsRepository(this._client);

  final GraphQLClient _client;

  @override
  Future<List<CardDeck>> listDecks() async {
    final rows = await fetchKgqlModels(
      _client,
      filter: const {'model_type': deckModelType},
      struct: const {
        'id': true,
        'name': true,
        'description': true,
        'updated_at': true,
        attrArchived: true,
        attrFromLanguage: true,
        attrToLanguage: true,
      },
    );
    final decks = rows.map(cardDeckFromModel).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return decks;
  }

  @override
  Future<List<StudyCard>> listCards() async {
    // A parent KGQL query returns child rows, but its struct can only project
    // fields known to the parent type. Fetch the child projection separately
    // so child-only attributes remain child-specific in the schema.
    final results = await Future.wait([
      fetchKgqlModels(
        _client,
        filter: const {'model_type': cardModelType},
        struct: _baseCardStruct,
      ),
      fetchKgqlModels(
        _client,
        filter: const {'model_type': languageCardModelType},
        struct: _languageCardStruct,
      ),
      fetchKgqlModels(
        _client,
        filter: const {'model_type': wordCardModelType},
        struct: _wordCardStruct,
      ),
    ]);
    final rowsById = <int, Model>{
      for (final result in results)
        for (final row in result) row.id: row,
    };
    return rowsById.values
        .map((row) => studyCardFromModel(row, relatedModels: rowsById))
        .whereType<StudyCard>()
        .toList();
  }

  @override
  Future<List<String>> listLanguages() async {
    final values = <String>{
      'French',
      'Hindi',
      'Japanese',
      'Malayalam',
      'Spanish',
      for (final deck in await listDecks()) ...[
        ?deck.fromLanguage,
        ?deck.toLanguage,
      ],
    }.toList()..sort();
    return values;
  }

  @override
  Future<void> addLanguage(String name) async {}

  @override
  Future<List<RelatedBook>> listBooks() async {
    try {
      final rows = await fetchKgqlModels(
        _client,
        filter: const {'model_type': bookModelType},
        struct: const {'id': true, 'name': true},
      );
      final books = rows.map((row) => RelatedBook(row.id, row.name)).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return books;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<int> createDeck({
    required String name,
    required String description,
    String? fromLanguage,
    String? toLanguage,
  }) {
    return setKgqlModel(
      _client,
      SetModelRequest(
        modelType: deckModelType,
        name: name,
        description: description,
        attributes: [
          SetModelAttribute(key: attrArchived, value: false),
          if (fromLanguage != null)
            SetModelAttribute(key: attrFromLanguage, value: fromLanguage),
          if (toLanguage != null)
            SetModelAttribute(key: attrToLanguage, value: toLanguage),
        ],
      ),
      auditSourceKind: 'nx_cards',
    );
  }

  @override
  Future<int> createCard({
    required CardContent content,
    required int deckId,
    int? sourceBookId,
  }) {
    return setKgqlModel(
      _client,
      SetModelRequest(
        modelType: content is LanguageCardContent
            ? wordCardModelType
            : cardModelType,
        name: content.front,
        attributes: [
          SetModelAttribute(
            key: attrCardDetails,
            value: cardDetailsJson(content),
          ),
          SetModelAttribute(key: attrSuspended, value: false),
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
        relations: [
          ModelRelation(modelType: deckModelType, link: [deckId]),
          if (sourceBookId != null)
            ModelRelation(modelType: bookModelType, link: [sourceBookId]),
        ],
      ),
      auditSourceKind: 'nx_cards',
    );
  }

  @override
  Future<void> updateCardContent({
    required int id,
    required CardContent content,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: id,
        name: content.front,
        attributes: [
          SetModelAttribute(
            key: attrCardDetails,
            value: cardDetailsJson(content),
          ),
          if (content case final LanguageCardContent languageContent)
            SetModelAttribute(
              key: attrLanguageDetails,
              value: languageDetailsJson(languageContent),
            ),
        ],
      ),
      auditSourceKind: 'nx_cards',
    );
  }

  @override
  Future<void> saveSchedule(StudyCard card) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: card.id,
        attributes: [
          SetModelAttribute(
            key: attrDueAt,
            value: card.nextDueAt?.toUtc().toIso8601String(),
            delete: card.nextDueAt == null,
          ),
          SetModelAttribute(key: attrSchedule, value: scheduleJson(card)),
          SetModelAttribute(
            key: attrReviewHistory,
            value: reviewHistoryJson(card),
          ),
        ],
      ),
      auditSourceKind: 'nx_cards',
    );
  }

  @override
  Future<void> setSuspended(StudyCard card, bool suspended) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: card.id,
        attributes: [SetModelAttribute(key: attrSuspended, value: suspended)],
      ),
      auditSourceKind: 'nx_cards',
    );
  }

  @override
  Future<void> setLearningStatus(StudyCard card, LearningStatus status) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: card.id,
        attributes: [
          SetModelAttribute(
            key: attrLearningStatus,
            value: status.storageValue,
          ),
        ],
      ),
      auditSourceKind: 'nx_cards',
    );
  }

  @override
  Future<void> deleteCard(int id) async {
    await setKgqlModel(
      _client,
      SetModelRequest(id: id, delete: true),
      auditSourceKind: 'nx_cards',
    );
  }
}

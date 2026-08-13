import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/data/remote/kgql/card_model_mapper.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_db/kgql.dart';

const baseCardStruct = <String, dynamic>{
  'id': true,
  'name': true,
  'description': true,
  'updated_at': true,
  attrDueAt: true,
  attrLearningStatus: true,
  attrSuspended: true,
  attrSchedule: true,
  attrReviewHistory: true,
  attrCardDetails: true,
  'tags': true,
  'model_type': {'id': true, 'name': true},
  bookModelType: {'id': true, 'name': true},
};

const languageCardStruct = <String, dynamic>{
  ...baseCardStruct,
  attrLanguageDetails: true,
  'relations': {
    'relation_id': true,
    'model_id': true,
    'model_type': true,
    'name': true,
    'relation_name': true,
  },
};

Future<List<StudyCard>> fetchKgqlCards(GraphQLClient client) async {
  final results = await Future.wait([
    fetchKgqlModels(
      client,
      filter: const {'model_type': cardModelType},
      struct: baseCardStruct,
    ),
    fetchKgqlModels(
      client,
      // KGQL projects tag systems from the filter type. Query lexical families
      // at their concrete roots so Word Category is not lost by filtering at
      // the LanguageFlashcard ancestor.
      filter: const {'model_type': wordCardModelType},
      struct: languageCardStruct,
    ),
    fetchKgqlModels(
      client,
      filter: const {'model_type': phraseCardModelType},
      struct: languageCardStruct,
    ),
    fetchKgqlModels(
      client,
      filter: const {'model_type': scriptCardModelType},
      struct: languageCardStruct,
    ),
  ]);
  final rowsById = <int, Model>{
    for (final result in results)
      for (final row in result) row.id: row,
  };
  return rowsById.values
      .map((row) => studyCardFromModel(row, relatedModels: rowsById))
      .whereType<StudyCard>()
      .toList(growable: false);
}

class KgqlCardsRepository implements CardsRepository {
  KgqlCardsRepository(this._client);

  final GraphQLClient _client;

  @override
  Future<List<StudyCard>> listCards() => fetchKgqlCards(_client);

  @override
  Future<List<String>> listLanguages() async {
    final values = <String>{
      for (final card in await listCards())
        if (card.language case final language? when language.isNotEmpty)
          language,
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
  Future<int> createCard({required CardContent content, int? sourceBookId}) {
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
        relations: [
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

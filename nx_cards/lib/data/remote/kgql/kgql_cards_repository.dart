import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/data/remote/kgql/card_model_mapper.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_db/kgql.dart';

const _cardStruct = <String, dynamic>{
  'id': true,
  'name': true,
  'description': true,
  'updated_at': true,
  attrDueAt: true,
  attrSuspended: true,
  attrSchedule: true,
  attrReviewHistory: true,
  attrTransliteration: true,
  attrAudioUrl: true,
  'last_reviewed_at': true,
  'stability': true,
  'difficulty': true,
  'scheduling_state': true,
  'learning_step': true,
  'review_count': true,
  'lapse_count': true,
  'tags': true,
  'model_type': {'id': true, 'name': true},
  deckModelType: {'id': true, 'name': true},
  bookModelType: {'id': true, 'name': true},
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
        'tags': true,
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
        struct: _cardStruct,
      ),
      fetchKgqlModels(
        _client,
        filter: const {'model_type': languageCardModelType},
        struct: _cardStruct,
      ),
    ]);
    final rowsById = <int, Model>{
      for (final row in results.first) row.id: row,
      for (final row in results.last) row.id: row,
    };
    return rowsById.values
        .map(studyCardFromModel)
        .whereType<StudyCard>()
        .toList();
  }

  @override
  Future<List<String>> listLanguages() =>
      _listTagNodes(deckModelType, deckLanguageTagSystem);

  @override
  Future<List<String>> listCardTags() =>
      _listTagNodes(cardModelType, cardTagsTagSystem, leavesOnly: true);

  @override
  Future<void> addLanguage(String name) {
    return _addTagNode(deckModelType, deckLanguageTagSystem, name);
  }

  @override
  Future<void> addCardTag(String name) {
    return _addTagNode(cardModelType, cardTagsTagSystem, name);
  }

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
    String? language,
  }) {
    return setKgqlModel(
      _client,
      SetModelRequest(
        modelType: deckModelType,
        name: name,
        description: description,
        attributes: [SetModelAttribute(key: attrArchived, value: false)],
        tags: language == null
            ? null
            : [
                SetModelTag(
                  system: deckLanguageTagSystem,
                  nodes: [language],
                  clear: true,
                ),
              ],
      ),
      auditSourceKind: 'nx_cards',
    );
  }

  @override
  Future<int> createCard({
    required CardContent content,
    required int deckId,
    required List<String> tags,
    int? sourceBookId,
  }) {
    return setKgqlModel(
      _client,
      SetModelRequest(
        modelType: content is LanguageCardContent
            ? languageCardModelType
            : cardModelType,
        name: content.front,
        description: content.back,
        attributes: [
          SetModelAttribute(key: attrSuspended, value: false),
          SetModelAttribute(key: attrSchedule, value: emptyScheduleJson()),
          SetModelAttribute(
            key: attrReviewHistory,
            value: reviewHistoryJson(const <CardReview>[]),
          ),
          if (content case LanguageCardContent(:final transliteration))
            SetModelAttribute(key: attrTransliteration, value: transliteration),
        ],
        relations: [
          ModelRelation(modelType: deckModelType, link: [deckId]),
          if (sourceBookId != null)
            ModelRelation(modelType: bookModelType, link: [sourceBookId]),
        ],
        tags: [
          SetModelTag(system: cardTagsTagSystem, nodes: tags, clear: true),
        ],
      ),
      auditSourceKind: 'nx_cards',
    );
  }

  @override
  Future<void> updateCardContent({
    required int id,
    required CardContent content,
    required List<String> tags,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: id,
        name: content.front,
        description: content.back,
        attributes: [
          if (content case LanguageCardContent(:final transliteration))
            SetModelAttribute(key: attrTransliteration, value: transliteration),
        ],
        tags: [
          SetModelTag(system: cardTagsTagSystem, nodes: tags, clear: true),
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
            value: card.dueAt!.toUtc().toIso8601String(),
          ),
          SetModelAttribute(key: attrSchedule, value: scheduleJson(card)),
          SetModelAttribute(
            key: attrReviewHistory,
            value: reviewHistoryJson(card.reviewHistory),
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
  Future<void> deleteCard(int id) async {
    await setKgqlModel(
      _client,
      SetModelRequest(id: id, delete: true),
      auditSourceKind: 'nx_cards',
    );
  }

  Future<List<String>> _listTagNodes(
    String modelType,
    String systemName, {
    bool leavesOnly = false,
  }) async {
    final schema = await fetchKgqlModelTypeByName(
      _client,
      modelType,
      struct: const {'id': true, 'name': true, 'tag_systems': true},
    );
    final systems = schema.tagSystems ?? const <TagSystem>[];
    final system = systems.where((row) => row.name == systemName).firstOrNull;
    if (system == null) return const [];
    final result = <String>[];
    void visit(TagNode node) {
      final children = node.children ?? const <TagNode>[];
      if (!leavesOnly || children.isEmpty) result.add(node.name);
      for (final child in children) {
        visit(child);
      }
    }

    for (final node in system.nodes) {
      visit(node);
    }
    return result;
  }

  Future<void> _addTagNode(
    String modelTypeName,
    String systemName,
    String rawName,
  ) async {
    final name = rawName.trim();
    if (name.isEmpty) return;
    final schema = await fetchKgqlModelTypeByName(_client, modelTypeName);
    final system = (schema.tagSystems ?? const <TagSystem>[])
        .where((row) => row.name == systemName)
        .firstOrNull;
    if (system == null) {
      throw StateError('Tag system "$systemName" was not found');
    }
    bool contains(TagNode node) {
      if (node.name.toLowerCase() == name.toLowerCase()) return true;
      return (node.children ?? const <TagNode>[]).any(contains);
    }

    if (system.nodes.any(contains)) return;
    final nodes = system.nodes.map(_tagNodeToRequest).toList()
      ..add(SetTagNodeRequest(name: name));
    await setKgqlModelType(
      _client,
      SetModelTypeRequest(
        id: schema.id,
        name: schema.name,
        typeKind: schema.typeKind ?? 'base',
        tagSystems: [
          SetTagSystemRequest(
            id: system.id,
            name: system.name,
            isHierarchical: system.isHierarchical,
            selectionMode: system.selectionMode,
            nodes: nodes,
          ),
        ],
      ),
      auditSourceKind: 'nx_cards',
    );
  }
}

SetTagNodeRequest _tagNodeToRequest(TagNode node) {
  final children = node.children ?? const <TagNode>[];
  return SetTagNodeRequest(
    id: node.id,
    name: node.name,
    children: children.isEmpty
        ? null
        : children.map(_tagNodeToRequest).toList(),
  );
}

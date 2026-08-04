import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_db/kgql.dart';

// Read-only compatibility for cards created before schedule JSON was adopted.
const _legacyLastReviewedAt = 'last_reviewed_at';
const _legacyStability = 'stability';
const _legacyDifficulty = 'difficulty';
const _legacySchedulingState = 'scheduling_state';
const _legacyLearningStep = 'learning_step';
const _legacyReviewCount = 'review_count';
const _legacyLapseCount = 'lapse_count';

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
  _legacyLastReviewedAt: true,
  _legacyStability: true,
  _legacyDifficulty: true,
  _legacySchedulingState: true,
  _legacyLearningStep: true,
  _legacyReviewCount: true,
  _legacyLapseCount: true,
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
    final decks = rows.map(_deckFromModel).toList()
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
    return rowsById.values.map(_cardFromModel).whereType<StudyCard>().toList();
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
          SetModelAttribute(key: attrSchedule, value: _emptyScheduleJson()),
          SetModelAttribute(
            key: attrReviewHistory,
            value: _reviewHistoryJson(const []),
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
          SetModelAttribute(key: attrSchedule, value: _scheduleJson(card)),
          SetModelAttribute(
            key: attrReviewHistory,
            value: _reviewHistoryJson(card.reviewHistory),
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

CardDeck _deckFromModel(Model model) {
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

StudyCard? _cardFromModel(Model model) {
  final decks = model.relations?[deckModelType] ?? const <Model>[];
  if (decks.isEmpty) return null;
  final deck = decks.first;
  final books = model.relations?[bookModelType] ?? const <Model>[];
  final book = books.firstOrNull;
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
    tags: model.tags?[cardTagsTagSystem] ?? const [],
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

Map<String, dynamic> _emptyScheduleJson() => const {
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

Map<String, dynamic> _scheduleJson(StudyCard card) => {
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

Map<String, dynamic> _reviewHistoryJson(List<CardReview> reviews) => {
  'version': 1,
  'items': reviews.map((review) => review.toJson()).toList(),
};

List<CardReview> _reviewHistoryFrom(Object? raw) {
  final json = _jsonMap(raw);
  final items = json['items'];
  if (items is! List) return const [];
  return items.map(CardReview.fromJson).whereType<CardReview>().toList();
}

Map<String, dynamic> _jsonMap(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return const {};
    }
  }
  return const {};
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

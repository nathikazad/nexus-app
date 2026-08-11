import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

const deckModelType = 'FlashcardDeck';
const cardModelType = 'Flashcard';
const languageCardModelType = 'LanguageFlashcard';
const wordCardModelType = 'Word';
const phraseCardModelType = 'Phrase';
const verbCardModelType = 'Verb';
const bookModelType = 'Book';

const wordPhrasesRelation = 'word_phrases';
const verbPhraseConjugationRelation = 'verb_phrase_conjugation';
const wordCategoryTagSystem = 'Word Category';

bool isLanguageCardModelType(String? name) =>
    name == languageCardModelType ||
    name == wordCardModelType ||
    name == phraseCardModelType ||
    name == verbCardModelType;

const attrArchived = 'archived';
const attrDueAt = 'due_at';
const attrSuspended = 'suspended';
const attrSchedule = 'schedule';
const attrReviewHistory = 'review_history';
const attrCardDetails = 'card_details';
const attrLanguageDetails = 'language_details';
const attrLearningStatus = 'learning_status';
const attrFromLanguage = 'from_language';
const attrToLanguage = 'to_language';
const _legacyAttrLanguage = 'language';

const cardDetailsJsonSchema = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['front', 'back'],
  'properties': {
    'front': {'type': 'string', 'minLength': 1},
    'back': {'type': 'string', 'minLength': 1},
  },
};

const languageDetailsJsonSchema = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['transliteration', 'audio_url', 'examples'],
  'properties': {
    'transliteration': {'type': 'string', 'minLength': 1},
    'audio_url': {
      'type': ['string', 'null'],
    },
    'examples': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['text', 'transliteration', 'translation'],
        'properties': {
          'text': {'type': 'string', 'minLength': 1},
          'transliteration': {'type': 'string', 'minLength': 1},
          'translation': {'type': 'string', 'minLength': 1},
          'audio_url': {
            'type': ['string', 'null'],
          },
        },
      },
    },
  },
};

const scheduleJsonSchema = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  r'$defs': {'cue_schedule': _cueScheduleJsonSchema},
  'required': ['version', 'algorithm', 'cues'],
  'properties': {
    'version': {'type': 'integer', 'const': 3},
    'algorithm': {'type': 'string', 'const': 'fsrs'},
    'cues': {
      'type': 'object',
      'additionalProperties': false,
      'required': ['from_language', 'to_language', 'transliteration'],
      'properties': {
        'from_language': {r'$ref': r'#/$defs/cue_schedule'},
        'to_language': {r'$ref': r'#/$defs/cue_schedule'},
        'transliteration': {r'$ref': r'#/$defs/cue_schedule'},
      },
    },
  },
};

const _cueScheduleJsonSchema = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  'required': [
    'enabled',
    'state',
    'step',
    'due_at',
    'last_reviewed_at',
    'stability',
    'difficulty',
    'review_count',
    'lapse_count',
  ],
  'properties': {
    'enabled': {'type': 'boolean'},
    'state': {
      'type': 'string',
      'enum': ['learning', 'review', 'relearning'],
    },
    'step': {
      'type': ['integer', 'null'],
      'minimum': 0,
    },
    'due_at': {
      'type': ['string', 'null'],
      'format': 'date-time',
    },
    'last_reviewed_at': {
      'type': ['string', 'null'],
      'format': 'date-time',
    },
    'stability': {
      'type': ['number', 'null'],
      'minimum': 0,
    },
    'difficulty': {
      'type': ['number', 'null'],
    },
    'review_count': {'type': 'integer', 'minimum': 0},
    'lapse_count': {'type': 'integer', 'minimum': 0},
  },
};

const reviewHistoryJsonSchema = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['version', 'items'],
  'properties': {
    'version': {'type': 'integer', 'const': 3},
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': [
          'id',
          'cue',
          'reviewed_at',
          'rating',
          'elapsed_seconds',
          'scheduled_seconds',
        ],
        'properties': {
          'id': {'type': 'string', 'minLength': 1},
          'cue': {
            'type': 'string',
            'enum': ['from_language', 'to_language', 'transliteration'],
          },
          'reviewed_at': {'type': 'string', 'format': 'date-time'},
          'rating': {'type': 'integer', 'minimum': 1, 'maximum': 4},
          'elapsed_seconds': {'type': 'integer', 'minimum': 0},
          'scheduled_seconds': {'type': 'integer', 'minimum': 0},
        },
      },
    },
  },
};

class CardsSchemaStatus {
  const CardsSchemaStatus({
    required this.deckReady,
    required this.cardReady,
    required this.languageCardReady,
  });

  final bool deckReady;
  final bool cardReady;
  final bool languageCardReady;
  bool get ready => deckReady && cardReady && languageCardReady;
}

Future<CardsSchemaStatus> inspectCardsSchema(GraphQLClient client) async {
  final deck = await _modelTypeOrNull(client, deckModelType);
  final card = await _modelTypeOrNull(client, cardModelType);
  final languageCard = await _modelTypeOrNull(client, languageCardModelType);
  return CardsSchemaStatus(
    deckReady:
        deck != null &&
        _hasAttributes(deck, const {
          attrArchived: 'boolean',
          attrFromLanguage: 'string',
          attrToLanguage: 'string',
        }) &&
        !(deck.attributes ?? const []).any(
          (attribute) => attribute.key == _legacyAttrLanguage,
        ) &&
        !(deck.tagSystems ?? const []).any(
          (system) => system.name == 'Language',
        ),
    cardReady:
        card != null &&
        _hasAttributeDefinitions(
          card,
          buildCardSchemaRequest().attributeDefinitions!,
        ) &&
        !(card.tagSystems ?? const []).any((system) => system.name == 'Tags'),
    languageCardReady:
        languageCard != null &&
        languageCard.parent?.name == cardModelType &&
        _hasAttributeDefinitions(
          languageCard,
          buildLanguageCardSchemaRequest().attributeDefinitions!,
        ),
  );
}

Future<ModelType?> _modelTypeOrNull(GraphQLClient client, String name) async {
  try {
    return await fetchKgqlModelTypeByName(client, name);
  } on StateError {
    return null;
  }
}

bool _hasAttributes(ModelType modelType, Map<String, String> expected) {
  final actual = {
    for (final definition
        in modelType.attributes ?? const <AttributeDefinition>[])
      if (definition.key != null) definition.key!: definition.valueType,
  };
  return expected.entries.every((entry) => actual[entry.key] == entry.value);
}

bool _hasAttributeDefinitions(
  ModelType modelType,
  List<AttributeDefinition> expected,
) {
  final actual = <String, AttributeDefinition>{
    for (final definition
        in modelType.attributes ?? const <AttributeDefinition>[])
      ?definition.key: definition,
  };
  return expected.every((desired) {
    final current = actual[desired.key];
    return current != null &&
        current.valueType == desired.valueType &&
        current.required == desired.required &&
        _deepEquals(current.constraints, desired.constraints);
  });
}

Future<void> bootstrapCardsSchema(GraphQLClient client) async {
  final deck = await _modelTypeOrNull(client, deckModelType);
  if (deck == null) {
    await setKgqlModelType(
      client,
      buildDeckSchemaRequest(),
      auditSourceKind: 'nx_cards',
    );
  } else {
    await _syncAttributeDefinitions(
      client,
      deck,
      buildDeckSchemaRequest().attributeDefinitions!,
    );
    await _migrateDeckLanguageTags(
      client,
      hasLegacyLanguageAttribute: (deck.attributes ?? const []).any(
        (attribute) => attribute.key == _legacyAttrLanguage,
      ),
    );
    await _removeLegacyDeckLanguageAttribute(client, deck);
    await _removeDeckLanguageTagSystem(client, deck);
  }

  final card = await _modelTypeOrNull(client, cardModelType);
  if (card == null) {
    await setKgqlModelType(
      client,
      buildCardSchemaRequest(),
      auditSourceKind: 'nx_cards',
    );
  } else {
    await _syncAttributeDefinitions(
      client,
      card,
      buildCardSchemaRequest().attributeDefinitions!,
    );
    await _removeCardTagSystem(client, card);
  }

  final languageCard = await _modelTypeOrNull(client, languageCardModelType);
  if (languageCard == null) {
    await setKgqlModelType(
      client,
      buildLanguageCardSchemaRequest(),
      auditSourceKind: 'nx_cards',
    );
  } else {
    await _syncAttributeDefinitions(
      client,
      languageCard,
      buildLanguageCardSchemaRequest().attributeDefinitions!,
    );
  }
}

Future<void> _migrateDeckLanguageTags(
  GraphQLClient client, {
  required bool hasLegacyLanguageAttribute,
}) async {
  final decks = await fetchKgqlModels(
    client,
    filter: const {'model_type': deckModelType},
    struct: {
      'id': true,
      'name': true,
      if (hasLegacyLanguageAttribute) _legacyAttrLanguage: true,
      attrFromLanguage: true,
      attrToLanguage: true,
      'tags': true,
    },
  );
  for (final deck in decks) {
    final existingFrom =
        deck.attributes?[attrFromLanguage]?.toString().trim() ?? '';
    final existingTo =
        deck.attributes?[attrToLanguage]?.toString().trim() ?? '';
    if (existingFrom.isNotEmpty && existingTo.isNotEmpty) continue;
    final legacy =
        deck.attributes?[_legacyAttrLanguage]?.toString().trim() ?? '';
    final tagged = deck.tags?['Language']?.firstOrNull?.trim() ?? '';
    final target = legacy.isNotEmpty ? legacy : tagged;
    if (target.isEmpty) continue;
    await setKgqlModel(
      client,
      SetModelRequest(
        id: deck.id,
        attributes: [
          if (existingFrom.isEmpty)
            SetModelAttribute(key: attrFromLanguage, value: 'English'),
          if (existingTo.isEmpty)
            SetModelAttribute(key: attrToLanguage, value: target),
        ],
      ),
      auditSourceKind: 'nx_cards',
    );
  }
}

Future<void> _removeLegacyDeckLanguageAttribute(
  GraphQLClient client,
  ModelType deck,
) async {
  final attribute = (deck.attributes ?? const [])
      .where((value) => value.key == _legacyAttrLanguage)
      .firstOrNull;
  if (attribute == null) return;
  await setKgqlModelType(
    client,
    SetModelTypeRequest(
      id: deck.id,
      name: deck.name,
      typeKind: deck.typeKind ?? 'base',
      attributeDefinitions: [
        AttributeDefinition(id: attribute.id, delete: true),
      ],
    ),
    auditSourceKind: 'nx_cards',
  );
}

Future<void> _removeDeckLanguageTagSystem(
  GraphQLClient client,
  ModelType deck,
) async {
  final system = (deck.tagSystems ?? const [])
      .where((value) => value.name == 'Language')
      .firstOrNull;
  if (system == null) return;
  await setKgqlModelType(
    client,
    SetModelTypeRequest(
      id: deck.id,
      name: deck.name,
      typeKind: deck.typeKind ?? 'base',
      tagSystems: [SetTagSystemRequest(id: system.id, delete: true)],
    ),
    auditSourceKind: 'nx_cards',
  );
}

Future<void> _removeCardTagSystem(GraphQLClient client, ModelType card) async {
  final system = (card.tagSystems ?? const [])
      .where((value) => value.name == 'Tags')
      .firstOrNull;
  if (system == null) return;
  await setKgqlModelType(
    client,
    SetModelTypeRequest(
      id: card.id,
      name: card.name,
      typeKind: card.typeKind ?? 'base',
      tagSystems: [SetTagSystemRequest(id: system.id, delete: true)],
    ),
    auditSourceKind: 'nx_cards',
  );
}

Future<void> _syncAttributeDefinitions(
  GraphQLClient client,
  ModelType modelType,
  List<AttributeDefinition> expected,
) async {
  final existing = {
    for (final definition
        in modelType.attributes ?? const <AttributeDefinition>[])
      if (definition.key != null) definition.key!: definition,
  };
  final changes = <AttributeDefinition>[];
  for (final desired in expected) {
    final definition = existing[desired.key];
    if (definition != null &&
        definition.valueType == desired.valueType &&
        definition.required == desired.required &&
        _deepEquals(definition.constraints, desired.constraints)) {
      continue;
    }
    changes.add(
      AttributeDefinition(
        id: definition?.id,
        key: desired.key,
        valueType: desired.valueType,
        required: desired.required,
        constraints: desired.constraints,
      ),
    );
  }
  if (changes.isEmpty) return;
  await setKgqlModelType(
    client,
    SetModelTypeRequest(
      id: modelType.id,
      name: modelType.name,
      typeKind: modelType.typeKind ?? 'base',
      attributeDefinitions: changes,
    ),
    auditSourceKind: 'nx_cards',
  );
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepEquals(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}

SetModelTypeRequest buildDeckSchemaRequest() {
  return SetModelTypeRequest(
    name: deckModelType,
    typeKind: 'base',
    description: 'A collection of cue-based spaced-repetition cards.',
    attributeDefinitions: [
      AttributeDefinition(
        key: attrArchived,
        valueType: 'boolean',
        required: true,
      ),
      AttributeDefinition(key: attrFromLanguage, valueType: 'string'),
      AttributeDefinition(key: attrToLanguage, valueType: 'string'),
    ],
  );
}

SetModelTypeRequest buildCardSchemaRequest() {
  return SetModelTypeRequest(
    name: cardModelType,
    typeKind: 'base',
    description:
        'A flashcard with structured content and independent cue-based FSRS state and review history.',
    attributeDefinitions: [
      AttributeDefinition(
        key: attrCardDetails,
        valueType: 'json',
        required: true,
        constraints: const {'json_schema': cardDetailsJsonSchema},
      ),
      AttributeDefinition(key: attrDueAt, valueType: 'datetime'),
      AttributeDefinition(
        key: attrSuspended,
        valueType: 'boolean',
        required: true,
      ),
      AttributeDefinition(
        key: attrSchedule,
        valueType: 'json',
        constraints: const {'json_schema': scheduleJsonSchema},
      ),
      AttributeDefinition(
        key: attrReviewHistory,
        valueType: 'json',
        constraints: const {'json_schema': reviewHistoryJsonSchema},
      ),
    ],
    relationshipTypes: [
      RelationshipType.fromName(
        deckModelType,
        multiplicity: 'one',
        relationName: 'in_deck',
      ),
      RelationshipType.fromName(
        bookModelType,
        multiplicity: 'one',
        relationName: 'source_book',
      ),
    ],
  );
}

SetModelTypeRequest buildLanguageCardSchemaRequest() {
  return SetModelTypeRequest(
    name: languageCardModelType,
    typeKind: 'base',
    description:
        'A language-learning flashcard with structured language details and optional reinforcement examples.',
    parent: ParentLink.fromName(cardModelType),
    attributeDefinitions: [
      AttributeDefinition(
        key: attrLanguageDetails,
        valueType: 'json',
        required: true,
        constraints: const {'json_schema': languageDetailsJsonSchema},
      ),
    ],
  );
}

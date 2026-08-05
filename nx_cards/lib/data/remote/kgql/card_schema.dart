import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

const deckModelType = 'FlashcardDeck';
const cardModelType = 'Flashcard';
const languageCardModelType = 'LanguageFlashcard';
const bookModelType = 'Book';

const deckLanguageTagSystem = 'Language';
const cardTagsTagSystem = 'Tags';

const attrArchived = 'archived';
const attrDueAt = 'due_at';
const attrSuspended = 'suspended';
const attrSchedule = 'schedule';
const attrReviewHistory = 'review_history';
const attrTransliteration = 'transliteration';
const attrAudioUrl = 'audio_url';

const scheduleJsonSchema = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['version', 'algorithm', 'front_to_back', 'back_to_front'],
  'properties': {
    'version': {'type': 'integer', 'const': 2},
    'algorithm': {'type': 'string', 'const': 'fsrs'},
    'front_to_back': _directionScheduleJsonSchema,
    'back_to_front': _directionScheduleJsonSchema,
  },
};

const _directionScheduleJsonSchema = <String, dynamic>{
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
  'required': ['version', 'front_to_back', 'back_to_front'],
  'properties': {
    'version': {'type': 'integer', 'const': 2},
    'front_to_back': _directionReviewHistoryJsonSchema,
    'back_to_front': _directionReviewHistoryJsonSchema,
  },
};

const _directionReviewHistoryJsonSchema = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['items'],
  'properties': {
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': [
          'id',
          'reviewed_at',
          'rating',
          'elapsed_seconds',
          'scheduled_seconds',
        ],
        'properties': {
          'id': {'type': 'string', 'minLength': 1},
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
        deck != null && _hasAttributes(deck, const {attrArchived: 'boolean'}),
    cardReady:
        card != null &&
        _hasAttributeDefinitions(
          card,
          buildCardSchemaRequest().attributeDefinitions!,
        ),
    languageCardReady:
        languageCard != null &&
        languageCard.parent?.name == cardModelType &&
        _hasAttributes(languageCard, const {
          attrTransliteration: 'string',
          attrAudioUrl: 'string',
        }),
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
    description: 'A collection of one-direction spaced-repetition cards.',
    attributeDefinitions: [
      AttributeDefinition(
        key: attrArchived,
        valueType: 'boolean',
        required: true,
      ),
    ],
    tagSystems: [
      SetTagSystemRequest(
        name: deckLanguageTagSystem,
        isHierarchical: false,
        selectionMode: 'exclusive',
        nodes: [
          SetTagNodeRequest(name: 'French'),
          SetTagNodeRequest(name: 'Japanese'),
          SetTagNodeRequest(name: 'Spanish'),
          SetTagNodeRequest(name: 'Hindi'),
          SetTagNodeRequest(name: 'Malayalam'),
        ],
      ),
    ],
  );
}

SetModelTypeRequest buildCardSchemaRequest() {
  return SetModelTypeRequest(
    name: cardModelType,
    typeKind: 'base',
    description:
        'A flashcard with independent front-to-back and back-to-front FSRS state and review history.',
    attributeDefinitions: [
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
    tagSystems: [
      SetTagSystemRequest(
        name: cardTagsTagSystem,
        isHierarchical: true,
        selectionMode: 'multiple',
        nodes: [
          SetTagNodeRequest(
            name: 'Topic',
            children: [
              SetTagNodeRequest(name: 'Script'),
              SetTagNodeRequest(name: 'Vocabulary'),
              SetTagNodeRequest(name: 'Grammar'),
            ],
          ),
          SetTagNodeRequest(
            name: 'Source',
            children: [SetTagNodeRequest(name: 'Book')],
          ),
        ],
      ),
    ],
  );
}

SetModelTypeRequest buildLanguageCardSchemaRequest() {
  return SetModelTypeRequest(
    name: languageCardModelType,
    typeKind: 'base',
    description:
        'A language-learning flashcard with English on the front and original script plus transliteration on the back.',
    parent: ParentLink.fromName(cardModelType),
    attributeDefinitions: [
      AttributeDefinition(
        key: attrTransliteration,
        valueType: 'string',
        required: true,
        constraints: const {'minLength': 1},
      ),
      AttributeDefinition(key: attrAudioUrl, valueType: 'string'),
    ],
  );
}

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

const cardModelType = 'Flashcard';
const languageCardModelType = 'LanguageFlashcard';
const wordCardModelType = 'Word';
const phraseCardModelType = 'Phrase';
const verbCardModelType = 'Verb';
const scriptCardModelType = 'Script';
const bookModelType = 'Book';

// Historical database name; now LanguageFlashcard -> LanguageFlashcard.
// From contains to; the reverse is Examples. Keep the name to preserve links.
const wordPhrasesRelation = 'word_phrases';
const verbPhraseConjugationRelation = 'verb_phrase_conjugation';
const wordCategoryTagSystem = 'Word Category';

bool isLanguageCardModelType(String? name) =>
    name == languageCardModelType ||
    name == wordCardModelType ||
    name == phraseCardModelType ||
    name == verbCardModelType ||
    name == scriptCardModelType;

const attrDueAt = 'due_at';
const attrSuspended = 'suspended';
const attrSchedule = 'schedule';
const attrReviewHistory = 'review_history';
const attrCardDetails = 'card_details';
const attrLanguageDetails = 'language_details';
const attrSpokenOnly = 'spoken_only';
const attrSimilarWordGroups = 'similar_word_groups';
const attrLearningState = 'learning_state';

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
    'audio_sha256': {
      'type': ['string', 'null'],
      'pattern': r'^[a-f0-9]{64}$',
    },
    'audio_bytes': {
      'type': ['integer', 'null'],
      'minimum': 1,
    },
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
          'audio_sha256': {
            'type': ['string', 'null'],
            'pattern': r'^[a-f0-9]{64}$',
          },
          'audio_bytes': {
            'type': ['integer', 'null'],
            'minimum': 1,
          },
          'audio_url': {
            'type': ['string', 'null'],
          },
        },
      },
    },
  },
};

const scheduleJsonSchema = <String, dynamic>{
  r'additionalProperties': false,
  r'properties': {
    r'algorithm': {r'const': r'fsrs', r'type': r'string'},
    r'cues': {
      r'type': r'object',
      r'additionalProperties': false,
      r'properties': {
        r'front_to_back': {r'$ref': r'#/$defs/cue_schedule'},
        r'back_to_front': {r'$ref': r'#/$defs/cue_schedule'},
      },
      r'required': [r'front_to_back', r'back_to_front'],
    },
    r'version': {r'const': 4, r'type': r'integer'},
  },
  r'required': [r'version', r'algorithm', r'cues'],
  r'type': r'object',
  r'$defs': {
    r'cue_schedule': {
      r'additionalProperties': false,
      r'properties': {
        r'difficulty': {
          r'type': [r'number', r'null'],
          r'minimum': 1,
          r'maximum': 10,
        },
        r'due_at': {
          r'format': r'date-time',
          r'type': [r'string', r'null'],
        },
        r'enabled': {r'type': r'boolean'},
        r'lapse_count': {r'minimum': 0, r'type': r'integer'},
        r'last_reviewed_at': {
          r'format': r'date-time',
          r'type': [r'string', r'null'],
        },
        r'review_count': {r'minimum': 0, r'type': r'integer'},
        r'stability': {
          r'minimum': 0,
          r'type': [r'number', r'null'],
        },
        r'state': {
          r'enum': [r'learning', r'review', r'relearning'],
          r'type': r'string',
        },
        r'step': {
          r'minimum': 0,
          r'type': [r'integer', r'null'],
        },
      },
      r'required': [
        r'enabled',
        r'state',
        r'step',
        r'due_at',
        r'last_reviewed_at',
        r'stability',
        r'difficulty',
        r'review_count',
        r'lapse_count',
      ],
      r'type': r'object',
    },
  },
};
const reviewHistoryJsonSchema = <String, dynamic>{
  r'additionalProperties': false,
  r'properties': {
    r'items': {
      r'items': {
        r'additionalProperties': false,
        r'properties': {
          r'cue': {
            r'enum': [r'front_to_back', r'back_to_front'],
            r'type': r'string',
          },
          r'elapsed_seconds': {r'minimum': 0, r'type': r'integer'},
          r'id': {r'minLength': 1, r'type': r'string'},
          r'rating': {r'maximum': 4, r'minimum': 1, r'type': r'integer'},
          r'reviewed_at': {r'format': r'date-time', r'type': r'string'},
          r'scheduled_seconds': {r'minimum': 0, r'type': r'integer'},
        },
        r'required': [
          r'id',
          r'cue',
          r'reviewed_at',
          r'rating',
          r'elapsed_seconds',
          r'scheduled_seconds',
        ],
        r'type': r'object',
      },
      r'type': r'array',
    },
    r'version': {r'const': 4, r'type': r'integer'},
  },
  r'required': [r'version', r'items'],
  r'type': r'object',
};
const languageScheduleJsonSchema = <String, dynamic>{
  r'additionalProperties': false,
  r'properties': {
    r'algorithm': {r'const': r'fsrs', r'type': r'string'},
    r'cues': {
      r'type': r'object',
      r'additionalProperties': false,
      r'properties': {
        r'meaning_to_sound': {r'$ref': r'#/$defs/cue_schedule'},
        r'meaning_to_script': {r'$ref': r'#/$defs/cue_schedule'},
        r'sound_to_meaning': {r'$ref': r'#/$defs/cue_schedule'},
        r'sound_to_script': {r'$ref': r'#/$defs/cue_schedule'},
        r'script_to_meaning': {r'$ref': r'#/$defs/cue_schedule'},
        r'script_to_sound': {r'$ref': r'#/$defs/cue_schedule'},
      },
      r'required': [
        r'meaning_to_sound',
        r'meaning_to_script',
        r'sound_to_meaning',
        r'sound_to_script',
        r'script_to_meaning',
        r'script_to_sound',
      ],
    },
    r'version': {r'const': 4, r'type': r'integer'},
  },
  r'required': [r'version', r'algorithm', r'cues'],
  r'type': r'object',
  r'$defs': {
    r'cue_schedule': {
      r'additionalProperties': false,
      r'properties': {
        r'difficulty': {
          r'type': [r'number', r'null'],
          r'minimum': 1,
          r'maximum': 10,
        },
        r'due_at': {
          r'format': r'date-time',
          r'type': [r'string', r'null'],
        },
        r'enabled': {r'type': r'boolean'},
        r'lapse_count': {r'minimum': 0, r'type': r'integer'},
        r'last_reviewed_at': {
          r'format': r'date-time',
          r'type': [r'string', r'null'],
        },
        r'review_count': {r'minimum': 0, r'type': r'integer'},
        r'stability': {
          r'minimum': 0,
          r'type': [r'number', r'null'],
        },
        r'state': {
          r'enum': [r'learning', r'review', r'relearning'],
          r'type': r'string',
        },
        r'step': {
          r'minimum': 0,
          r'type': [r'integer', r'null'],
        },
      },
      r'required': [
        r'enabled',
        r'state',
        r'step',
        r'due_at',
        r'last_reviewed_at',
        r'stability',
        r'difficulty',
        r'review_count',
        r'lapse_count',
      ],
      r'type': r'object',
    },
  },
};
const languageReviewHistoryJsonSchema = <String, dynamic>{
  r'additionalProperties': false,
  r'properties': {
    r'items': {
      r'items': {
        r'additionalProperties': false,
        r'properties': {
          r'cue': {
            r'enum': [
              r'meaning_to_sound',
              r'meaning_to_script',
              r'sound_to_meaning',
              r'sound_to_script',
              r'script_to_meaning',
              r'script_to_sound',
            ],
            r'type': r'string',
          },
          r'elapsed_seconds': {r'minimum': 0, r'type': r'integer'},
          r'id': {r'minLength': 1, r'type': r'string'},
          r'rating': {r'maximum': 4, r'minimum': 1, r'type': r'integer'},
          r'reviewed_at': {r'format': r'date-time', r'type': r'string'},
          r'scheduled_seconds': {r'minimum': 0, r'type': r'integer'},
        },
        r'required': [
          r'id',
          r'cue',
          r'reviewed_at',
          r'rating',
          r'elapsed_seconds',
          r'scheduled_seconds',
        ],
        r'type': r'object',
      },
      r'type': r'array',
    },
    r'version': {r'const': 4, r'type': r'integer'},
  },
  r'required': [r'version', r'items'],
  r'type': r'object',
};

class CardsSchemaStatus {
  const CardsSchemaStatus({
    required this.cardReady,
    required this.languageCardReady,
  });
  final bool cardReady;
  final bool languageCardReady;
  bool get ready => cardReady && languageCardReady;
}

Future<CardsSchemaStatus> inspectCardsSchema(GraphQLClient client) async {
  final card = await _modelTypeOrNull(client, cardModelType);
  final languageCard = await _modelTypeOrNull(client, languageCardModelType);
  return CardsSchemaStatus(
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
        _deepEquals(
          current.constraints ?? const {},
          desired.constraints ?? const {},
        );
  });
}

Future<void> bootstrapCardsSchema(GraphQLClient client) async {
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
        _deepEquals(
          definition.constraints ?? const {},
          desired.constraints ?? const {},
        )) {
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

SetModelTypeRequest buildCardSchemaRequest() {
  return SetModelTypeRequest(
    name: cardModelType,
    parent: ParentLink.fromName('Digital Nouns'),
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
        key: attrLearningState,
        valueType: 'string',
        required: true,
        constraints: const {
          'default': 'future',
          'enum': ['future', 'practice', 'recall'],
        },
      ),
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
        key: 'schedule',
        valueType: 'json',
        constraints: const {'json_schema': languageScheduleJsonSchema},
      ),

      AttributeDefinition(
        key: 'review_history',
        valueType: 'json',
        constraints: const {'json_schema': languageReviewHistoryJsonSchema},
      ),

      AttributeDefinition(
        key: attrSpokenOnly,
        valueType: 'boolean',
        required: false,
        constraints: const {'default': false},
      ),
      AttributeDefinition(
        key: attrLanguageDetails,
        valueType: 'json',
        required: true,
        constraints: const {'json_schema': languageDetailsJsonSchema},
      ),
    ],
  );
}

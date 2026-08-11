import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/data/remote/kgql/card_model_mapper.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_db/kgql.dart';

void main() {
  test('maps related Phrase card content into Word examples', () {
    final phrase = Model(
      id: 22,
      name: 'He has good talent.',
      modelTypeId: 4,
      modelType: ModelType(id: 4, name: phraseCardModelType),
      attributes: const <String, Object?>{
        attrCardDetails: <String, Object?>{
          'front': 'He has good talent.',
          'back': 'അവന് നല്ല കഴിവുണ്ട്.',
        },
        attrLanguageDetails: <String, Object?>{
          'transliteration': 'avan nalla kazhivundu',
          'audio_url': '/cards/audio/example.mp3',
          'examples': <Object?>[],
        },
      },
    );
    final word = Model(
      id: 11,
      name: 'talent',
      modelTypeId: 3,
      modelType: ModelType(id: 3, name: wordCardModelType),
      attributes: const <String, Object?>{
        attrCardDetails: <String, Object?>{'front': 'talent', 'back': 'കഴിവ്'},
        attrLanguageDetails: <String, Object?>{
          'transliteration': 'kazhivu',
          'audio_url': null,
          'examples': <Object?>[],
        },
        attrCurrentlyLearning: true,
      },
      tags: const <String, List<String>>{
        'Language': <String>['Malayalam'],
        'Part of Speech': <String>['Noun'],
      },
      relationsList: <Relation>[
        Relation(
          relationId: 1,
          modelId: 7,
          modelType: deckModelType,
          name: 'Malayalam Nouns',
        ),
        Relation(
          relationId: 2,
          modelId: 22,
          modelType: phraseCardModelType,
          relationName: wordPhrasesRelation,
        ),
      ],
    );

    final card = studyCardFromModel(
      word,
      relatedModels: <int, Model>{22: phrase},
    );

    expect(card, isNotNull);
    expect(card!.modelTypeName, wordCardModelType);
    expect(card.currentlyLearning, isTrue);
    expect(card.tags['Language'], <String>['Malayalam']);
    expect(card.tags['Part of Speech'], <String>['Noun']);
    final content = card.content as LanguageCardContent;
    expect(content.examples, hasLength(1));
    expect(content.examples.single.text, 'അവന് നല്ല കഴിവുണ്ട്.');
    expect(content.examples.single.translation, 'He has good talent.');
    expect(content.examples.single.audioUrl, '/cards/audio/example.mp3');
  });

  test('maps related Phrase attributes embedded in a native sync relation', () {
    final word = Model(
      id: 11,
      name: 'talent',
      modelTypeId: 3,
      modelType: ModelType(id: 3, name: wordCardModelType),
      attributes: const <String, Object?>{
        attrCardDetails: <String, Object?>{'front': 'talent', 'back': 'കഴിവ്'},
        attrLanguageDetails: <String, Object?>{
          'transliteration': 'kazhivu',
          'audio_url': null,
          'examples': <Object?>[],
        },
      },
      relationsList: <Relation>[
        Relation(
          relationId: 1,
          modelId: 7,
          modelType: deckModelType,
          name: 'Malayalam Nouns',
        ),
        Relation(
          relationId: 2,
          modelId: 22,
          modelType: phraseCardModelType,
          relationName: wordPhrasesRelation,
          relatedAttributes: const <String, Object?>{
            attrCardDetails: <String, Object?>{
              'front': 'He has good talent.',
              'back': 'അവന് നല്ല കഴിവുണ്ട്.',
            },
            attrLanguageDetails: <String, Object?>{
              'transliteration': 'avan nalla kazhivundu',
              'audio_url': '/cards/audio/example.mp3',
              'examples': <Object?>[],
            },
          },
        ),
      ],
    );

    final content = studyCardFromModel(word)!.content as LanguageCardContent;

    expect(content.examples.single.transliteration, 'avan nalla kazhivundu');
  });

  test('does not treat a Phrase reverse Word relation as an example', () {
    final phrase = Model(
      id: 22,
      name: 'He has good talent.',
      modelTypeId: 4,
      modelType: ModelType(id: 4, name: phraseCardModelType),
      attributes: const <String, Object?>{
        attrCardDetails: <String, Object?>{
          'front': 'He has good talent.',
          'back': 'അവന് നല്ല കഴിവുണ്ട്.',
        },
        attrLanguageDetails: <String, Object?>{
          'transliteration': 'avan nalla kazhivundu',
          'audio_url': null,
          'examples': <Object?>[],
        },
      },
      relationsList: <Relation>[
        Relation(
          relationId: 1,
          modelId: 8,
          modelType: deckModelType,
          name: 'Phrases 1',
        ),
        Relation(
          relationId: 2,
          modelId: 11,
          modelType: wordCardModelType,
          relationName: wordPhrasesRelation,
        ),
      ],
    );
    final word = Model(
      id: 11,
      name: 'talent',
      modelTypeId: 3,
      modelType: ModelType(id: 3, name: wordCardModelType),
      attributes: const <String, Object?>{
        attrCardDetails: <String, Object?>{'front': 'talent', 'back': 'കഴിവ്'},
        attrLanguageDetails: <String, Object?>{
          'transliteration': 'kazhivu',
          'audio_url': null,
          'examples': <Object?>[],
        },
      },
    );

    final content =
        studyCardFromModel(
              phrase,
              relatedModels: <int, Model>{11: word},
            )!.content
            as LanguageCardContent;

    expect(content.examples, isEmpty);
  });
}

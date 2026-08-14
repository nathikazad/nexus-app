import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_mapper.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_schema.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_db/kgql.dart';

void main() {
  test('maps a deckless Book flashcard and preserves its source', () {
    final model = Model(
      id: 5385,
      name: 'Why validate demand?',
      modelTypeId: 66,
      modelType: ModelType(id: 66, name: cardModelType),
      attributes: const <String, Object?>{
        attrCardDetails: <String, Object?>{
          'front': 'Why validate demand?',
          'back': 'To avoid scaling an unproven model.',
        },
        attrSuspended: false,
        attrLearningStatus: 'not_started',
      },
      relationsList: <Relation>[
        Relation(
          relationId: 9,
          modelId: 4195,
          modelType: bookModelType,
          name: 'The Four Steps to the Epiphany',
          relationName: 'flashcard_book',
        ),
      ],
    );

    final card = studyCardFromModel(model);

    expect(card, isNotNull);
    expect(card, isNotNull);
    expect(card!.sourceBookId, 4195);
    expect(card.sourceBookName, 'The Four Steps to the Epiphany');
  });

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
        attrLearningStatus: 'learning',
      },
      tags: const <String, List<String>>{
        'Language': <String>['Malayalam'],
        'Part of Speech': <String>['Noun'],
      },
      relationsList: <Relation>[
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
    expect(card.learningStatus, LearningStatus.learning);
    expect(card.tags['Language'], <String>['Malayalam']);
    expect(card.tags['Part of Speech'], <String>['Noun']);
    expect(card.studyCategory, 'Noun');
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
    expect(
      studyCardFromModel(
        phrase,
        relatedModels: <int, Model>{11: word},
      )!.linkedWordIds,
      <int>{11},
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_mapper.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_schema.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_db/kgql.dart';

void main() {
  test('same relationship supports contains and examples at every level', () {
    Model row(int id, String text, String type, List<Relation> links) => Model(
      id: id,
      name: text,
      modelTypeId: id,
      modelType: ModelType(id: id, name: type),
      attributes: {
        attrCardDetails: {'front': text, 'back': text},
        attrLanguageDetails: {'transliteration': text, 'examples': []},
      },
      relationsList: links,
    );
    Relation link(int id, String type, String direction) => Relation(
      relationId: id,
      modelId: id,
      modelType: type,
      relationName: wordPhrasesRelation,
      relation: direction,
    );
    final character = row(1, '午', 'Word', [link(2, 'Word', 'parent')]);
    final word = row(2, '下午', 'Word', [
      link(1, 'Word', 'child'),
      link(3, 'Phrase', 'parent'),
    ]);
    final phrase = row(3, '下午见', 'Phrase', [link(2, 'Word', 'child')]);
    final models = {1: character, 2: word, 3: phrase};
    final mapped = models.map(
      (id, model) =>
          MapEntry(id, studyCardFromModel(model, relatedModels: models)!),
    );
    expect(mapped[1]!.linkedWordIds, isEmpty);
    expect(mapped[2]!.linkedWordIds, {1});
    expect(mapped[3]!.linkedWordIds, {2});
    final examples = (mapped[1]!.content as LanguageCardContent).examples;
    expect(examples.single.text, '下午');
    expect(examples.single.cardId, 2);
    expect(LanguageExample.fromJson(examples.single.toJson()).cardId, 2);
    expect(
      (mapped[2]!.content as LanguageCardContent).examples.single.cardId,
      3,
    );
    expect((mapped[3]!.content as LanguageCardContent).examples, isEmpty);
  });

  test('maps a deckless Book flashcard and preserves its source', () {
    final model = Model(
      id: 5385,
      name: 'Why validate demand?',
      description: 'A shared note for this card.',
      modelTypeId: 66,
      modelType: ModelType(id: 66, name: cardModelType),
      attributes: const <String, Object?>{
        attrCardDetails: <String, Object?>{
          'front': 'Why validate demand?',
          'back': 'To avoid scaling an unproven model.',
        },
        attrSuspended: false,
        attrLearningState: 'future',
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
    expect(card!.notes, 'A shared note for this card.');
    expect(card.copyWith(suspended: true).notes, card.notes);
    expect(card.sourceBookId, 4195);
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
        attrLearningState: 'practice',
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
    expect(card!.modelTypeName, languageCardModelType);
    expect(card.learningStatus, LearningStatus.practice);
    expect(card.tags['Language'], <String>['Malayalam']);
    expect(card.tags['Category'], <String>['Noun']);
    expect(card.categories, contains('Noun'));
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

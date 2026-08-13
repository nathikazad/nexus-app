import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_schema.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_api.dart';
import 'package:nx_cards/browser/browser.dart';

void main() {
  test('creates language content as a Word', () async {
    Request? captured;
    final repository = KgqlCardApi(
      _client((request) {
        captured = request;
        return const {
          '__typename': 'Mutation',
          'setKgqlModels': {
            '__typename': 'SetKgqlModelsPayload',
            'json': {'id': 42},
          },
        };
      }),
    );

    final id = await repository.createCard(
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
    );

    expect(id, 42);
    final input = captured!.variables['input'] as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    expect(data['model_type'], wordCardModelType);
    expect(data['name'], 'talent');
    expect(data, isNot(contains('description')));
    final attributes = data['attributes'] as List<dynamic>;
    expect(
      attributes.cast<Map<String, dynamic>>().singleWhere(
        (row) => row['key'] == attrLearningStatus,
      )['value'],
      LearningStatus.notStarted.storageValue,
    );
    final cardDetails =
        attributes.singleWhere(
              (row) => (row as Map<String, dynamic>)['key'] == attrCardDetails,
            )
            as Map<String, dynamic>;
    expect(cardDetails['value'], {'front': 'talent', 'back': 'കഴിവ്'});
    final languageDetails =
        attributes.singleWhere(
              (row) =>
                  (row as Map<String, dynamic>)['key'] == attrLanguageDetails,
            )
            as Map<String, dynamic>;
    expect(languageDetails['value'], {
      'transliteration': 'kazhivu',
      'audio_url': null,
      'examples': <Object?>[],
    });
    final schedule =
        attributes.singleWhere(
              (row) => (row as Map<String, dynamic>)['key'] == attrSchedule,
            )
            as Map<String, dynamic>;
    final scheduleValue = schedule['value'] as Map<String, dynamic>;
    final cues = scheduleValue['cues'] as Map<String, dynamic>;
    expect((cues['from_language'] as Map<String, dynamic>)['enabled'], isTrue);
    expect((cues['to_language'] as Map<String, dynamic>)['enabled'], isTrue);
    expect(
      (cues['transliteration'] as Map<String, dynamic>)['enabled'],
      isTrue,
    );
  });

  test('maps a LanguageFlashcard response to typed language content', () async {
    final requestedTypes = <String>[];
    final repository = KgqlCardApi(
      _client((request) {
        final filter = request.variables['filter'] as Map<String, dynamic>;
        final requestedType = filter['model_type']! as String;
        requestedTypes.add(requestedType);
        if (requestedType == phraseCardModelType ||
            requestedType == scriptCardModelType) {
          return {'__typename': 'Query', 'getKgqlModels': <Object?>[]};
        }
        return {
          '__typename': 'Query',
          'getKgqlModels': [
            {
              'id': 42,
              'name': 'talent',
              'model_type_id': 67,
              'card_details': {'front': 'talent', 'back': 'കഴിവ്'},
              if (requestedType != cardModelType)
                'language_details': {
                  'transliteration': 'kazhivu',
                  'audio_url': null,
                  'examples': <Object?>[
                    {
                      'text': 'അവന് നല്ല കഴിവുണ്ട്.',
                      'transliteration': 'avan nalla kazhivundu',
                      'translation': 'He has good talent.',
                      'audio_url': null,
                    },
                  ],
                },
              'suspended': false,
              'schedule': {
                'version': 3,
                'algorithm': 'fsrs',
                'cues': {
                  'from_language': _emptySchedule(enabled: true),
                  'to_language': _emptySchedule(enabled: true),
                  'transliteration': _emptySchedule(enabled: true),
                },
              },
              'review_history': {'version': 3, 'items': <Object?>[]},
              'learning_status': 'learning',
              'model_type': {'id': 67, 'name': wordCardModelType},
              'tags': <String, dynamic>{
                'Language': <String>['Malayalam'],
                if (requestedType == wordCardModelType)
                  'Word Category': <String>['Noun'],
              },
            },
          ],
        };
      }),
    );

    final cards = await repository.listCards();

    expect(cards, hasLength(1));
    expect(cards.single.content, isA<LanguageCardContent>());
    final content = cards.single.content as LanguageCardContent;
    expect(content.english, 'talent');
    expect(content.originalScript, 'കഴിവ്');
    expect(content.transliteration, 'kazhivu');
    expect(content.examples.single.translation, 'He has good talent.');
    expect(cards.single.scheduleFor(StudyCue.fromLanguage).enabled, isTrue);
    expect(cards.single.scheduleFor(StudyCue.toLanguage).enabled, isTrue);
    expect(cards.single.learningStatus, LearningStatus.learning);
    expect(cards.single.tags['Word Category'], ['Noun']);
    expect(requestedTypes.toSet(), {
      cardModelType,
      wordCardModelType,
      phraseCardModelType,
      scriptCardModelType,
    });
  });
}

Map<String, Object?> _emptySchedule({required bool enabled}) =>
    <String, Object?>{
      'enabled': enabled,
      'state': 'learning',
      'step': 0,
      'due_at': null,
      'last_reviewed_at': null,
      'stability': null,
      'difficulty': null,
      'review_count': 0,
      'lapse_count': 0,
    };

GraphQLClient _client(Map<String, dynamic> Function(Request) respond) {
  final link = Link.function((request, [forward]) {
    return Stream.value(
      Response(
        response: const {},
        data: respond(request),
        context: request.context,
      ),
    );
  });
  return GraphQLClient(cache: GraphQLCache(), link: link);
}

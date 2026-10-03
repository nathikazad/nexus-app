import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_schema.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_api.dart';
import 'package:nx_cards/browser/browser.dart';

void main() {
  test(
    'bulk spoken-only activation sends one mutation with both attributes',
    () async {
      final requests = <Request>[];
      final repository = KgqlCardApi(
        _client((request) {
          requests.add(request);
          return const {
            '__typename': 'Mutation',
            'setKgqlModels': {
              '__typename': 'SetKgqlModelsPayload',
              'json': {'id': 42},
            },
          };
        }),
      );
      final card = StudyCard(
        id: 42,
        content: const LanguageCardContent(
          english: 'word',
          originalScript: '字',
          transliteration: 'zi',
        ),
        schedules: {
          for (final direction in StudyCue.values)
            direction: CardSchedule.initial(
              enabled: direction != StudyCue.backToFront,
            ),
        },
        reviewHistory: {},
        suspended: false,
      );
      await repository.setLearningStatus(
        card,
        LearningStatus.recall,
        spokenOnly: true,
      );
      final data = (requests.single.variables['input'] as Map)['data'] as Map;
      expect(data['attributes'], [
        {'key': 'spoken_only', 'value': true},
        {'key': 'learning_state', 'value': 'recall'},
      ]);
    },
  );

  test(
    'simultaneous dashboard and language reads share one request, then refresh',
    () async {
      final gate = Completer<void>();
      var requests = 0;
      final repository = KgqlCardApi(
        GraphQLClient(
          cache: GraphQLCache(),
          link: Link.function((request, [forward]) async* {
            requests++;
            await gate.future;
            yield Response(
              data: {'__typename': 'Query', 'getKgqlModels': <Object?>[]},
              response: const {},
            );
          }),
        ),
      );
      final cards = repository.listCards();
      final languages = repository.listLanguages();
      gate.complete();
      await Future.wait([cards, languages]);
      expect(requests, 2);
      await repository.listCards();
      expect(requests, 4);
    },
  );

  test('creates one LanguageFlashcard type', () async {
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
    expect(data['model_type'], languageCardModelType);
    expect(data['name'], 'talent');
    expect(data, isNot(contains('description')));
    final attributes = data['attributes'] as List<dynamic>;
    expect(
      attributes.cast<Map<String, dynamic>>().singleWhere(
        (row) => row['key'] == attrLearningState,
      )['value'],
      'future',
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
      'audio_sha256': null,
      'audio_bytes': null,
      'examples': <Object?>[],
    });
    final schedule =
        attributes.singleWhere(
              (row) => (row as Map<String, dynamic>)['key'] == attrSchedule,
            )
            as Map<String, dynamic>;
    final scheduleValue = schedule['value'] as Map<String, dynamic>;
    final cues = scheduleValue['cues'] as Map<String, dynamic>;
    expect(
      (cues['meaning_to_script'] as Map<String, dynamic>)['enabled'],
      isTrue,
    );
    expect(
      (cues['script_to_meaning'] as Map<String, dynamic>)['enabled'],
      isTrue,
    );
    expect(
      (cues['meaning_to_sound'] as Map<String, dynamic>)['enabled'],
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
                  'audio_sha256': null,
                  'audio_bytes': null,
                  'examples': <Object?>[
                    {
                      'text': 'അവന് നല്ല കഴിവുണ്ട്.',
                      'transliteration': 'avan nalla kazhivundu',
                      'translation': 'He has good talent.',
                      'audio_url': null,
                      'audio_sha256': null,
                      'audio_bytes': null,
                    },
                  ],
                },
              'suspended': false,
              'schedule': {
                'version': 4,
                'algorithm': 'fsrs',
                'cues': {
                  'meaning_to_script': _emptySchedule(enabled: true),
                  'script_to_meaning': _emptySchedule(enabled: true),
                  'transliteration': _emptySchedule(enabled: true),
                },
              },
              'review_history': {'version': 4, 'items': <Object?>[]},
              'learning_state': 'practice',
              'model_type': {'id': 67, 'name': wordCardModelType},
              'tags': <String, dynamic>{
                'Language': <String>['Malayalam'],
                if (requestedType == languageCardModelType)
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
    expect(cards.single.scheduleFor(StudyCue.meaningToScript).enabled, isTrue);
    expect(cards.single.scheduleFor(StudyCue.scriptToMeaning).enabled, isTrue);
    expect(cards.single.learningStatus, LearningStatus.practice);
    expect(cards.single.tags['Category'], ['Noun']);
    expect(requestedTypes.toSet(), {cardModelType, languageCardModelType});
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

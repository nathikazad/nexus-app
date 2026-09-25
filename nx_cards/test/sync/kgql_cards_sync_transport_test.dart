import 'package:nx_db/src/core/client/graphql_client.dart'
    show bindTestClientDomain;
import '../../../nx_modules/nx_db/test/support/app_sync_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart' show printNode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/sync/remote/kgql_sync_transport.dart';
import 'package:nx_cards/browser/browser.dart';

void main() {
  test(
    'hash download preserves embedded examples, tags and source links',
    () async {
      Request? captured;
      final transport = KgqlCardsSyncTransport(
        _client((request) {
          captured = request;
          final legacy = {
            'syncCards': {
              'manifest': [
                {'id': 11, 'hash': 'v2:abc'},
              ],
              'deleted_ids': [],
              'cards': [
                {
                  'id': 11,
                  'hash': 'v2:abc',
                  'card': {
                    'id': 11,
                    'name': 'day',
                    'model_type_id': 3,
                    'model_type': {'id': 3, 'name': 'Word'},
                    'attributes': {
                      'card_details': {'front': 'day', 'back': '日'},
                      'language_details': {'transliteration': 'rì'},
                    },
                    'tags': {
                      'Language': ['Chinese'],
                      'Word Category': ['Noun'],
                    },
                    'relations': [
                      {
                        'model_id': 12,
                        'model_type': 'Word',
                        'name': 'birthday',
                        'relation_name': 'word_phrases',
                        'relation': 'parent',
                        'related_attributes': {
                          'card_details': {'front': 'birthday', 'back': '生日'},
                          'language_details': {
                            'transliteration': 'shēngrì',
                            'audio_url': '/birthday.mp3',
                          },
                        },
                      },
                      {
                        'model_id': 50,
                        'model_type': 'Book',
                        'name': 'Chinese',
                        'relation_name': 'flashcard_book',
                      },
                    ],
                  },
                },
              ],
            },
          };
          final content = legacy['syncCards']!;
          return appSyncFixture(request.variables, [
            for (final card in content['cards'] as List)
              {'id': card['id'], 'hash': card['hash'], 'payload': card['card']},
          ]);
        }),
      );
      final bundle = await transport.downloadCards({11});
      expect(
        printNode(captured!.operation.document),
        contains('appSyncSnapshot'),
      );
      expect(captured!.variables['itemIds'], [11]);
      final card = bundle.cards.single.card;
      expect(card.sourceBookId, 50);
      expect(card.tags['Category'], ['Noun']);
      final example = (card.content as LanguageCardContent).examples.single;
      expect(example.cardId, 12);
      expect(example.text, '生日');
      expect(example.audioUrl, '/birthday.mp3');
    },
  );
  test('missing manifest is an error, never an empty library', () async {
    final transport = KgqlCardsSyncTransport(
      _client(
        (_) => {
          'syncCards': {'cards': [], 'deleted_ids': []},
        },
      ),
    );
    await expectLater(transport.cardManifest(), throwsA(anything));
  });
  test('mutateCard sends the complete JSON scheduling aggregate', () async {
    Request? captured;
    final transport = KgqlCardsSyncTransport(
      _client((request) {
        captured = request;
        return const <String, Object?>{
          '__typename': 'Mutation',
          'mutateCardLibrary': <String, Object?>{
            'status': 'APPLIED',
            'id': 11,
            'updated_at': '2026-08-04T12:00:00Z',
          },
        };
      }),
    );

    final result = await transport.mutateCard(
      _card(),
      clientUpdatedAt: DateTime.utc(2026, 8, 4, 12),
    );

    expect(
      printNode(captured!.operation.document),
      contains('mutateCardLibrary'),
    );
    final data = captured!.variables['data'] as Map<String, dynamic>;
    final attributes = data['attributes'] as List<dynamic>;
    final schedule = attributes.cast<Map<String, dynamic>>().singleWhere(
      (value) => value['key'] == 'schedule',
    );
    final scheduleValue = schedule['value'] as Map<String, dynamic>;
    expect(
      ((scheduleValue['cues'] as Map<String, dynamic>)['from_language']
          as Map<String, dynamic>)['review_count'],
      1,
    );
    expect(
      ((scheduleValue['cues'] as Map<String, dynamic>)['to_language']
          as Map<String, dynamic>)['review_count'],
      0,
    );
    final languageDetails = attributes.cast<Map<String, dynamic>>().singleWhere(
      (value) => value['key'] == 'language_details',
    );
    expect(
      (languageDetails['value'] as Map<String, dynamic>)['examples'],
      isEmpty,
    );
    expect(
      attributes.cast<Map<String, dynamic>>().singleWhere(
        (value) => value['key'] == 'learning_state',
      )['value'],
      'inactive',
    );
    expect(result.status, CardMutationStatus.applied);
    expect(result.status, CardMutationStatus.applied);
  });
}

GraphQLClient _client(Map<String, Object?> Function(Request) respond) {
  final link = Link.function((request, [forward]) {
    return Stream<Response>.value(
      Response(
        response: const <String, Object?>{},
        data: respond(request),
        context: request.context,
      ),
    );
  });
  return bindTestClientDomain(
    GraphQLClient(cache: GraphQLCache(), link: link),
    1,
  );
}

StudyCard _card() => StudyCard(
  id: 11,
  content: const LanguageCardContent(
    english: 'talent',
    originalScript: 'കഴിവ്',
    transliteration: 'kazhivu',
    audioUrl: '/cards/audio/1/11.mp3',
    examples: <LanguageExample>[
      LanguageExample(
        text: 'അവന് നല്ല കഴിവുണ്ട്.',
        transliteration: 'avan nalla kazhivundu',
        translation: 'He has good talent.',
      ),
    ],
  ),
  schedules: <StudyCue, CardSchedule>{
    StudyCue.fromLanguage: CardSchedule(
      enabled: true,
      dueAt: DateTime.utc(2026, 8, 5),
      lastReviewedAt: DateTime.utc(2026, 8, 4),
      stability: 3.5,
      difficulty: 5,
      schedulingState: 'review',
      learningStep: null,
      reviewCount: 1,
      lapseCount: 0,
    ),
    StudyCue.toLanguage: const CardSchedule.initial(enabled: true),
    StudyCue.transliteration: const CardSchedule.initial(enabled: true),
  },
  reviewHistory: const <StudyCue, List<CardReview>>{
    StudyCue.fromLanguage: <CardReview>[],
    StudyCue.toLanguage: <CardReview>[],
    StudyCue.transliteration: <CardReview>[],
  },
  suspended: false,
  updatedAt: DateTime.utc(2026, 8, 4),
);

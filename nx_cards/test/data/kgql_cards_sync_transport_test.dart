import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart' show printNode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/data/remote/kgql/kgql_cards_sync_transport.dart';
import 'package:nx_cards/domain/cards_models.dart';

void main() {
  test('maps a canonical language-card deck bundle', () async {
    Request? captured;
    final transport = KgqlCardsSyncTransport(
      _client((request) {
        captured = request;
        return <String, Object?>{
          '__typename': 'Query',
          'syncCardDecks': <String, Object?>{
            'decks': <Object?>[
              <String, Object?>{
                'id': 7,
                'hash': 'deck-hash',
                'bundle': <String, Object?>{
                  'deck': <String, Object?>{
                    'id': 7,
                    'name': 'Malayalam',
                    'description': 'Basic words',
                    'model_type_id': 60,
                    'updated_at': '2026-08-04T10:00:00Z',
                    'model_type': <String, Object?>{
                      'id': 60,
                      'name': 'FlashcardDeck',
                    },
                    'attributes': <String, Object?>{
                      'archived': false,
                      'from_language': 'English',
                      'to_language': 'Malayalam',
                    },
                  },
                  'cards': <Object?>[
                    <String, Object?>{
                      'id': 11,
                      'name': 'talent',
                      'model_type_id': 62,
                      'updated_at': '2026-08-04T10:00:00Z',
                      'model_type': <String, Object?>{'id': 62, 'name': 'Word'},
                      'attributes': <String, Object?>{
                        'suspended': false,
                        'card_details': <String, Object?>{
                          'front': 'talent',
                          'back': 'കഴിവ്',
                        },
                        'language_details': <String, Object?>{
                          'transliteration': 'kazhivu',
                          'audio_url': '/cards/audio/1/11.mp3',
                          'examples': <Object?>[],
                        },
                        'schedule': <String, Object?>{
                          'version': 3,
                          'algorithm': 'fsrs',
                          'cues': <String, Object?>{
                            'from_language': _emptySchedule(enabled: true),
                            'to_language': _emptySchedule(enabled: true),
                            'transliteration': _emptySchedule(enabled: true),
                          },
                        },
                        'review_history': <String, Object?>{
                          'version': 3,
                          'items': <Object?>[],
                        },
                      },
                      'tags': <String, Object?>{
                        'Tags': <String>['Vocabulary'],
                      },
                      'relations': <Object?>[
                        <String, Object?>{
                          'model_id': 7,
                          'model_type': 'FlashcardDeck',
                          'name': 'Malayalam',
                          'relation_name': 'in_deck',
                        },
                        <String, Object?>{
                          'model_id': 22,
                          'model_type': 'Phrase',
                          'name': 'He has good talent.',
                          'relation_name': 'word_phrases',
                          'related_attributes': <String, Object?>{
                            'card_details': <String, Object?>{
                              'front': 'He has good talent.',
                              'back': 'അവന് നല്ല കഴിവുണ്ട്.',
                            },
                            'language_details': <String, Object?>{
                              'transliteration': 'avan nalla kazhivundu',
                              'audio_url': '/cards/audio/example.mp3',
                              'examples': <Object?>[],
                            },
                          },
                        },
                      ],
                    },
                  ],
                },
              },
            ],
            'deleted_ids': <Object?>[],
          },
        };
      }),
    );

    final bundle = await transport.syncDecks(
      manifest: const <CardDeckManifestEntry>[
        CardDeckManifestEntry(deckId: 7, serverHash: 'old-hash'),
      ],
      deckIds: <int>{7},
    );

    expect(printNode(captured!.operation.document), contains('syncCardDecks'));
    expect(captured!.variables['deckIds'], <int>[7]);
    expect(bundle.decks.single.serverHash, 'deck-hash');
    expect(bundle.decks.single.deck.fromLanguage, 'English');
    expect(bundle.decks.single.deck.toLanguage, 'Malayalam');
    final card = bundle.decks.single.cards.single;
    expect(card.deckId, 7);
    expect(card.content, isA<LanguageCardContent>());
    expect((card.content as LanguageCardContent).transliteration, 'kazhivu');
    expect(
      (card.content as LanguageCardContent).examples.single.translation,
      'He has good talent.',
    );
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
            'deck_hashes': <Object?>[
              <String, Object?>{'id': 7, 'hash': 'new-hash'},
            ],
            'deleted_deck_ids': <Object?>[],
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
    expect(result.status, CardMutationStatus.applied);
    expect(result.deckHashes.single.serverHash, 'new-hash');
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
  return GraphQLClient(cache: GraphQLCache(), link: link);
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
  deckId: 7,
  deckName: 'Malayalam',
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

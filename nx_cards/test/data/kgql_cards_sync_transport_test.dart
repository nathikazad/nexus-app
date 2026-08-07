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
                    'attributes': <String, Object?>{'archived': false},
                    'tags': <String, Object?>{
                      'Language': <String>['Malayalam'],
                    },
                  },
                  'cards': <Object?>[
                    <String, Object?>{
                      'id': 11,
                      'name': 'talent',
                      'model_type_id': 62,
                      'updated_at': '2026-08-04T10:00:00Z',
                      'model_type': <String, Object?>{
                        'id': 62,
                        'name': 'LanguageFlashcard',
                      },
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
                          'version': 2,
                          'algorithm': 'fsrs',
                          'front_to_back': _emptySchedule(enabled: true),
                          'back_to_front': _emptySchedule(enabled: true),
                        },
                        'review_history': <String, Object?>{
                          'version': 2,
                          'front_to_back': <String, Object?>{
                            'items': <Object?>[],
                          },
                          'back_to_front': <String, Object?>{
                            'items': <Object?>[],
                          },
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
    expect(bundle.decks.single.deck.language, 'Malayalam');
    final card = bundle.decks.single.cards.single;
    expect(card.deckId, 7);
    expect(card.content, isA<LanguageCardContent>());
    expect((card.content as LanguageCardContent).transliteration, 'kazhivu');
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
      (scheduleValue['front_to_back'] as Map<String, dynamic>)['review_count'],
      1,
    );
    expect(
      (scheduleValue['back_to_front'] as Map<String, dynamic>)['review_count'],
      0,
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
  ),
  deckId: 7,
  deckName: 'Malayalam',
  tags: const <String>['Vocabulary'],
  schedules: <StudyDirection, CardSchedule>{
    StudyDirection.frontToBack: CardSchedule(
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
    StudyDirection.backToFront: const CardSchedule.initial(enabled: true),
  },
  reviewHistory: const <StudyDirection, List<CardReview>>{
    StudyDirection.frontToBack: <CardReview>[],
    StudyDirection.backToFront: <CardReview>[],
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

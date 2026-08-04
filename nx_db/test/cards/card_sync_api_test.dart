import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart' show printNode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/cards.dart';
import 'package:nx_db/kgql.dart';

import '../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('mutateCardLibrary sends timestamp and parses aggregate hashes',
      () async {
    final client = MockGraphQLClient();
    MutationOptions? captured;
    when(() => client.mutate(any())).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.single as MutationOptions;
      return QueryResult(
        options: MutationOptions(document: gql('mutation { __typename }')),
        source: QueryResultSource.network,
        data: const <String, Object?>{
          'mutateCardLibrary': <String, Object?>{
            'status': 'APPLIED',
            'id': 42,
            'updated_at': '2026-08-04T12:00:00',
            'deck_hashes': <Object?>[
              <String, Object?>{'id': 7, 'hash': 'deck-hash'},
            ],
            'deleted_deck_ids': <Object?>[],
            'entity': <String, Object?>{'id': 42, 'name': 'Front'},
          },
        },
      );
    });

    final result = await mutateCardLibrary(
      client,
      SetModelRequest(id: 42, name: 'Front'),
      clientUpdatedAt: DateTime.utc(2026, 8, 4, 12),
    );

    expect(printNode(captured!.document), contains('mutateCardLibrary'));
    expect(captured!.variables['clientUpdatedAt'], '2026-08-04T12:00:00.000Z');
    expect(result.status, CardLibraryMutationStatus.applied);
    expect(result.entityId, 42);
    expect(result.deckHashes.single.deckId, 7);
    expect(result.deckHashes.single.syncHash, 'deck-hash');
    expect(result.entity?['name'], 'Front');
  });

  test('syncCardDecks sorts target ids and parses bundles and deletes',
      () async {
    final client = MockGraphQLClient();
    QueryOptions? captured;
    when(() => client.query(any())).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.single as QueryOptions;
      return QueryResult(
        options: QueryOptions(document: gql('query { __typename }')),
        source: QueryResultSource.network,
        data: const <String, Object?>{
          'syncCardDecks': <String, Object?>{
            'decks': <Object?>[
              <String, Object?>{
                'id': 7,
                'hash': 'new-hash',
                'bundle': <String, Object?>{
                  'deck': <String, Object?>{'id': 7, 'name': 'Malayalam'},
                  'cards': <Object?>[],
                },
              },
            ],
            'deleted_ids': <Object?>[8],
          },
        },
      );
    });

    final result = await syncCardDecks(
      client,
      manifest: const <Map<String, Object?>>[
        <String, Object?>{'id': 7, 'hash': 'old-hash'},
      ],
      deckIds: <int>{9, 7},
    );

    expect(printNode(captured!.document), contains('syncCardDecks'));
    expect(captured!.variables['deckIds'], <int>[7, 9]);
    expect(result.decks.single.deckId, 7);
    expect(result.decks.single.syncHash, 'new-hash');
    expect(result.decks.single.bundle['cards'], isEmpty);
    expect(result.deletedIds, <int>[8]);
  });
}

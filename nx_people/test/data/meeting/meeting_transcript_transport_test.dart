import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_people/data/meeting/meeting_transcripts.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';

void main() {
  test(
    'query and subscription decode the server contracts and pass meeting ID',
    () async {
      final requested = <String>[];
      final client = GraphQLClient(
        cache: GraphQLCache(),
        link: Link.function((request, [forward]) {
          expect(request.variables, {'id': 99});
          final field = request.operation.document.definitions.first.toString();
          requested.add(field);
          final subscription =
              request.operation.document ==
              gql(
                r'subscription($id:Int!){meetingTranscriptsChanged(meetingId:$id)}',
              );
          final rows = [
            {'transcript_id': 1, 'text': 'Live speech', 'status': 'recording'},
          ];
          return Stream.value(
            Response(
              response: const {},
              data: subscription
                  ? {
                      'meetingTranscriptsChanged': {
                        'status': 'ready',
                        'transcripts': rows,
                      },
                    }
                  : {'meetingTranscripts': rows},
            ),
          );
        }),
      );
      final scope = ProviderContainer(
        overrides: [
          graphqlClientProvider.overrideWithValue(client),
          peopleOfflineStoreProvider.overrideWithValue(null),
        ],
      );
      final repo = scope.read(meetingTranscriptsRepositoryProvider);
      expect((await repo.fetch(99)).single['text'], 'Live speech');
      expect((await repo.subscribe(99).first).single['text'], 'Live speech');
      expect(requested, hasLength(2));
      scope.dispose();
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_notes/data/ai/note_transcript_service.dart';

void main() {
  test('loads the transcript related to the requested document', () async {
    final link = Link.function((request, [forward]) {
      return Stream<Response>.value(
        const Response(
          response: <String, Object?>{},
          data: <String, Object?>{
            '__typename': 'Query',
            'getKgqlModels': <Object?>[
              <String, Object?>{
                'id': 4450,
                'model_type_id': 1,
                'Transcript': <Object?>[
                  <String, Object?>{
                    'id': 91,
                    'name': 'Note 4450 AI Transcript',
                    'model_type_id': 2,
                    'messages': <String, Object?>{
                      '2026-08-06T12:00:00Z': <String, Object?>{
                        'sender': 'Human',
                        'message': 'Explain chapter ten',
                      },
                    },
                  },
                ],
              },
            ],
          },
        ),
      );
    });
    final client = GraphQLClient(
      link: link,
      cache: GraphQLCache(store: InMemoryStore()),
    );

    final transcript = await NoteTranscriptService(
      client: client,
    ).loadForDocument(4450);

    expect(transcript?.id, 91);
    expect(transcript?.sortedMessages.single.message, 'Explain chapter ten');
  });
}

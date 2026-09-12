import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_books/data/book/kgql_reading_history.dart';
import 'package:nx_documents/nx_documents.dart';

void main() {
  test(
    'EPUB resolves JSON pointer while summary resolves its relation',
    () async {
      final calls = <Map<String, dynamic>>[];
      final client = GraphQLClient(
        cache: GraphQLCache(store: InMemoryStore()),
        link: Link.function((request, [forward]) async* {
          calls.add(request.variables);
          final filter = request.variables['filter'] as Map;
          yield Response(
            response: const {},
            data: {
              '__typename': 'Query',
              'getKgqlModels': [
                if (filter['model_type'] == 'Transcript')
                  {
                    'id': 99,
                    'name': 'EPUB conversation',
                    'messages': {
                      '001': {'sender': 'Agent', 'message': 'EPUB answer'},
                    },
                  }
                else
                  {
                    'id': 7,
                    'name': 'Book title',
                    'book_file': {'transcript_id': 99},
                    'Transcript': [
                      {
                        'id': 88,
                        'name': 'Summary conversation',
                        'messages': {
                          '001': {
                            'sender': 'Agent',
                            'message': 'Summary answer',
                          },
                        },
                      },
                    ],
                  },
              ],
            },
          );
        }),
      );
      final epub = await fetchReadingHistory(
        client,
        const DocumentIdentity(id: 7, modelType: 'EpubBook'),
      );
      expect(epub.title, 'Book title');
      expect(epub.messages.single.text, 'EPUB answer');
      expect((calls.last['filter'] as Map)['filters'], [
        {'key': 'id', 'op': '=', 'value': '99'},
      ]);
      final summary = await fetchReadingHistory(
        client,
        const DocumentIdentity(id: 7, modelType: 'Book'),
      );
      expect(summary.messages.single.text, 'Summary answer');
      final clearTargets = await fetchReadingTranscripts(
        client,
        const DocumentIdentity(id: 7, modelType: 'EpubBook'),
      );
      expect(clearTargets.map((t) => t.id), [99]);
    },
  );
}

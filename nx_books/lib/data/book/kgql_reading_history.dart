import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_documents/nx_documents.dart';
import '../../domain/book/reading_history.dart';
import '../../domain/book/reading_history_codec.dart';

Future<ReadingHistory> fetchReadingHistory(
  GraphQLClient client,
  DocumentIdentity identity,
) async {
  final rows = await fetchKgqlModels(
    client,
    filter: {
      'model_type': identity.modelType,
      'filters': [
        {'key': 'id', 'op': '=', 'value': '${identity.id}'},
      ],
    },
    struct: const {
      'id': true,
      'name': true,
      'Transcript': {'id': true, 'messages': true},
    },
  ).timeout(const Duration(seconds: 12));
  if (rows.isEmpty) throw StateError('Document not found');
  final transcripts = rows.first.relations?['Transcript'];
  return ReadingHistory(
    rows.first.name,
    transcripts == null || transcripts.isEmpty
        ? []
        : readingMessagesFromHistory(transcripts.first.attributes?['messages']),
  );
}

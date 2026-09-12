import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_documents/nx_documents.dart';
import '../../domain/book/reading_history.dart';
import '../../domain/book/reading_history_codec.dart';

Future<ReadingHistory> fetchReadingHistory(
  GraphQLClient client,
  DocumentIdentity identity,
) async {
  final (title, transcripts) = await _fetchReadingSource(client, identity);
  return ReadingHistory(
    title,
    transcripts.isEmpty
        ? []
        : readingMessagesFromHistory(transcripts.first.attributes?['messages']),
  );
}

/// EPUB is a local conversation scope, not a KGQL model type.
Future<List<Model>> fetchReadingTranscripts(
  GraphQLClient client,
  DocumentIdentity identity,
) async => (await _fetchReadingSource(client, identity)).$2;

Future<(String, List<Model>)> _fetchReadingSource(
  GraphQLClient client,
  DocumentIdentity identity,
) async {
  final epub = identity.modelType == 'EpubBook';
  final rows = await fetchKgqlModels(
    client,
    filter: {
      'model_type': epub ? 'Book' : identity.modelType,
      'filters': [
        {'key': 'id', 'op': '=', 'value': '${identity.id}'},
      ],
    },
    struct: {
      'id': true,
      'name': true,
      if (epub) 'book_file': true,
      if (!epub) 'Transcript': {'id': true, 'name': true, 'messages': true},
    },
  ).timeout(const Duration(seconds: 12));
  if (rows.isEmpty) throw StateError('Document not found');
  if (!epub) {
    return (rows.first.name, rows.first.relations?['Transcript'] ?? <Model>[]);
  }
  final file = rows.first.attributes?['book_file'];
  final transcriptId = file is Map ? file['transcript_id'] : null;
  if (transcriptId == null) return (rows.first.name, <Model>[]);
  final transcripts = await fetchKgqlModels(
    client,
    filter: {
      'model_type': 'Transcript',
      'filters': [
        {'key': 'id', 'op': '=', 'value': '$transcriptId'},
      ],
    },
    struct: const {'id': true, 'name': true, 'messages': true},
  ).timeout(const Duration(seconds: 12));
  if (transcripts.isEmpty) throw StateError('EPUB transcript unavailable');
  return (rows.first.name, transcripts);
}

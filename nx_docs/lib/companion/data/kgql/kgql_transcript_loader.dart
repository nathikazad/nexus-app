import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_docs/companion/note_transcript.dart';

class KgqlTranscriptLoader implements NoteTranscriptLoader {
  KgqlTranscriptLoader({required GraphQLClient client}) : _client = client;

  final GraphQLClient _client;

  @override
  Future<NoteTranscript?> loadForDocument(int documentId) async {
    final documents = await fetchKgqlModels(
      _client,
      filter: <String, dynamic>{
        'model_type': 'Document',
        'filters': <Map<String, String>>[
          <String, String>{
            'key': 'id',
            'op': '=',
            'value': documentId.toString(),
          },
        ],
      },
      struct: const <String, dynamic>{
        'id': true,
        'Transcript': <String, dynamic>{
          'id': true,
          'name': true,
          'model_type_id': true,
          'messages': true,
        },
      },
    );
    if (documents.isEmpty) return null;
    final related = documents.first.relations?['Transcript'];
    if (related == null || related.isEmpty) return null;

    final transcript = related.first;
    dynamic messages = transcript.attributes?['messages'];
    if (messages is String) {
      try {
        messages = jsonDecode(messages);
      } catch (_) {
        return null;
      }
    }
    if (messages is! Map) return null;
    final parsed = parseTranscriptFromGraphqlResponse(<String, dynamic>{
      'id': transcript.id,
      'messages': Map<String, dynamic>.from(messages),
    });
    if (parsed == null) return null;
    return NoteTranscript(
      id: parsed.id,
      messages: parsed.sortedMessages
          .map(
            (message) => NoteTranscriptMessage(
              timestamp: message.timestamp,
              sender: message.sender,
              message: message.message,
            ),
          )
          .toList(growable: false),
    );
  }
}

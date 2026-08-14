import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_docs/companion/data/kgql/kgql_transcript_loader.dart';
import 'package:nx_docs/companion/note_transcript.dart';

final noteTranscriptLoaderProvider = Provider<NoteTranscriptLoader>((ref) {
  return KgqlTranscriptLoader(client: ref.watch(graphqlClientProvider));
});

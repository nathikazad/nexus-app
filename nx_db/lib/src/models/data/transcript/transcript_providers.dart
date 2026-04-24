import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';

import '../../domain/transcript/transcript.dart';
import '../../domain/transcript/transcript_repository.dart';
import 'kgql_transcript_repository.dart';

int _currentUserIdInt(Ref ref) {
  final idStr = ref.read(userIdProvider);
  if (idStr == null) {
    throw StateError('Not authenticated');
  }
  final id = int.tryParse(idStr);
  if (id == null) {
    throw StateError('Invalid user id: $idStr');
  }
  return id;
}

/// Default KGQL [TranscriptRepository] for the current session.
final transcriptRepositoryProvider = Provider<TranscriptRepository>(
  (ref) => KgqlTranscriptRepository(
    client: ref.watch(graphqlClientProvider),
    currentUserId: () => _currentUserIdInt(ref),
  ),
);

/// Current user’s transcript (null when not logged in or no data).
final currentTranscriptProvider = FutureProvider<Transcript?>((ref) async {
  final user = await ref.watch(authProvider.future);
  if (user == null) return null;
  return ref.watch(transcriptRepositoryProvider).getCurrent();
});

/// New messages for [transcriptId] from the GraphQL subscription.
final transcriptMessageStreamProvider =
    StreamProvider.family<TranscriptMessage, int>((ref, transcriptId) {
  return ref.watch(transcriptRepositoryProvider).watchMessages(transcriptId);
});

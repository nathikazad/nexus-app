import 'transcript.dart';

/// Transcript query / mutation / subscription (current user’s conversation).
abstract class TranscriptRepository {
  /// Latest transcript for the current user (from `getCurrentTranscript`).
  Future<Transcript?> getCurrent();

  Future<void> addMessage({
    required int transcriptId,
    required String sender,
    required String message,
  });

  Stream<TranscriptMessage> watchMessages(int transcriptId);
}

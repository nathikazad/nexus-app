import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';

/// Testable boundary for loading transcripts and streaming new messages.
abstract class VoiceTranscriptSource {
  Future<Transcript?> getTranscript();

  Stream<TranscriptMessage> streamMessages(int transcriptId);
}

/// Default implementation backed by [TranscriptService].
class NxDbVoiceTranscriptSource implements VoiceTranscriptSource {
  @override
  Future<Transcript?> getTranscript() => TranscriptService.getTranscript();

  @override
  Stream<TranscriptMessage> streamMessages(int transcriptId) =>
      TranscriptService.streamMessages(transcriptId);
}

/// Override in tests with a fake [VoiceTranscriptSource].
final voiceTranscriptSourceProvider = Provider<VoiceTranscriptSource>((ref) {
  return NxDbVoiceTranscriptSource();
});

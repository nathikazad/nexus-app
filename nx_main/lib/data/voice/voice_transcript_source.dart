import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/transcript.dart';

/// Testable boundary for loading transcripts and streaming new messages.
abstract class VoiceTranscriptSource {
  Future<Transcript?> getTranscript();

  Stream<TranscriptMessage> streamMessages(int transcriptId);
}

/// Default implementation backed by [TranscriptRepository] from [transcriptRepositoryProvider].
class NxDbVoiceTranscriptSource implements VoiceTranscriptSource {
  NxDbVoiceTranscriptSource(this._ref);

  final Ref _ref;

  @override
  Future<Transcript?> getTranscript() {
    return _ref.read(transcriptRepositoryProvider).getCurrent();
  }

  @override
  Stream<TranscriptMessage> streamMessages(int transcriptId) {
    return _ref.read(transcriptRepositoryProvider).watchMessages(transcriptId);
  }
}

/// Override in tests with a fake [VoiceTranscriptSource].
final voiceTranscriptSourceProvider = Provider<VoiceTranscriptSource>((ref) {
  return NxDbVoiceTranscriptSource(ref);
});

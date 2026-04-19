import 'dart:async';

import 'package:nx_db/nx_db.dart';
import 'package:nexus_voice_assistant/data/voice/voice_transcript_source.dart';

class FakeVoiceTranscriptSource implements VoiceTranscriptSource {
  Transcript? transcript;
  Object? getTranscriptError;

  final Map<int, StreamController<TranscriptMessage>> _streams = {};

  @override
  Future<Transcript?> getTranscript() async {
    if (getTranscriptError != null) {
      throw getTranscriptError!;
    }
    return transcript;
  }

  @override
  Stream<TranscriptMessage> streamMessages(int transcriptId) {
    final c = _streams.putIfAbsent(
      transcriptId,
      () => StreamController<TranscriptMessage>.broadcast(),
    );
    return c.stream;
  }

  StreamController<TranscriptMessage>? controllerFor(int transcriptId) =>
      _streams[transcriptId];

  void dispose() {
    for (final c in _streams.values) {
      unawaited(c.close());
    }
    _streams.clear();
  }
}

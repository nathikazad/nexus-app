import 'package:nx_db/nx_db.dart';
import 'package:nexus_voice_assistant/domain/voice/voice_transcript.dart';

VoiceTranscriptMessage mapTranscriptMessage(TranscriptMessage m) {
  return VoiceTranscriptMessage(
    message: m.message,
    isFromUser: m.isFromUser,
    timestamp: m.timestamp,
  );
}

VoiceTranscript? mapTranscript(Transcript? t) {
  if (t == null) return null;
  final mapped = <String, VoiceTranscriptMessage>{};
  for (final e in t.messages.entries) {
    mapped[e.key] = mapTranscriptMessage(e.value);
  }
  return VoiceTranscript(id: t.id, messages: mapped);
}

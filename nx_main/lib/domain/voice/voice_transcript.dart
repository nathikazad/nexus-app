/// One message in the voice assistant transcript (UI layer).
class VoiceTranscriptMessage {
  const VoiceTranscriptMessage({
    required this.message,
    required this.isFromUser,
    required this.timestamp,
  });

  final String message;
  final bool isFromUser;
  final String timestamp;
}

/// Transcript snapshot for the voice assistant screen.
class VoiceTranscript {
  const VoiceTranscript({
    required this.id,
    required this.messages,
  });

  final int id;
  final Map<String, VoiceTranscriptMessage> messages;

  List<VoiceTranscriptMessage> get sortedMessages {
    final sortedKeys = messages.keys.toList()..sort();
    return sortedKeys.map((k) => messages[k]!).toList();
  }

  VoiceTranscript copyWithMessage(VoiceTranscriptMessage message) {
    final next = Map<String, VoiceTranscriptMessage>.from(messages);
    next[message.timestamp] = message;
    return VoiceTranscript(id: id, messages: next);
  }
}

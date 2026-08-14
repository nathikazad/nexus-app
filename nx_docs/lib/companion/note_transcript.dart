class NoteTranscriptMessage {
  const NoteTranscriptMessage({
    required this.timestamp,
    required this.sender,
    required this.message,
  });

  final String timestamp;
  final String sender;
  final String message;
}

class NoteTranscript {
  const NoteTranscript({required this.id, required this.messages});

  final int id;
  final List<NoteTranscriptMessage> messages;

  List<NoteTranscriptMessage> get sortedMessages {
    return List<NoteTranscriptMessage>.of(messages)
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
  }
}

abstract interface class NoteTranscriptLoader {
  Future<NoteTranscript?> loadForDocument(int documentId);
}

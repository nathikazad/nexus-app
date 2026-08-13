/// Represents a single message in a transcript
class TranscriptMessage {
  final String timestamp;
  final String sender;
  final String message;

  TranscriptMessage({
    required this.timestamp,
    required this.sender,
    required this.message,
  });

  bool get isFromUser => sender == 'Human';

  factory TranscriptMessage.fromJson(Map<String, dynamic> json) {
    return TranscriptMessage(
      timestamp: json['timestamp'] as String,
      sender: json['sender'] as String,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'sender': sender,
      'message': message,
    };
  }
}

/// Represents a transcript with its messages
class Transcript {
  final int id;
  final Map<String, TranscriptMessage> messages;

  Transcript({
    required this.id,
    required this.messages,
  });

  Transcript copyWithMessage(TranscriptMessage message) {
    final newMessages = Map<String, TranscriptMessage>.from(messages);
    newMessages[message.timestamp] = message;
    return Transcript(id: id, messages: newMessages);
  }

  List<TranscriptMessage> get sortedMessages {
    final sortedKeys = messages.keys.toList()..sort();
    return sortedKeys.map((key) => messages[key]!).toList();
  }

  factory Transcript.fromJson(Map<String, dynamic> json) {
    final messagesMap = <String, TranscriptMessage>{};

    final messagesJson = json['messages'] as Map<String, dynamic>?;
    if (messagesJson != null) {
      messagesJson.forEach((timestamp, messageData) {
        if (messageData is Map<String, dynamic>) {
          messagesMap[timestamp] = TranscriptMessage(
            timestamp: timestamp,
            sender: messageData['sender'] as String? ?? '',
            message: messageData['message'] as String? ?? '',
          );
        }
      });
    }

    return Transcript(
      id: json['id'] as int,
      messages: messagesMap,
    );
  }
}

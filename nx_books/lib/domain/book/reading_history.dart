class ReadingMessage {
  const ReadingMessage(this.role, this.text, {this.turn});
  final String role;
  final String text;
  final String? turn;
}

class ReadingHistory {
  const ReadingHistory(this.title, this.messages);
  final String title;
  final List<ReadingMessage> messages;
}

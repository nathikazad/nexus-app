class Interaction {
  String userQuery;
  String aiResponse;
  final DateTime timestamp;
  String? userAudioFilePath;

  Interaction({
    required this.userQuery,
    required this.aiResponse,
    required this.timestamp,
    this.userAudioFilePath,
  });

  void addToAiResponse(String word) {
    aiResponse += word;
  }

  void addToUserQuery(String word) {
    userQuery += word;
  }

  void setUserAudioFilePath(String filePath) {
    userAudioFilePath = filePath;
  }
}

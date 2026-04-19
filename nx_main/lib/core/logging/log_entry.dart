class LogEntry {
  final DateTime timestamp;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'message': message,
    };
  }

  static LogEntry fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      message: json['message'] as String,
    );
  }
}


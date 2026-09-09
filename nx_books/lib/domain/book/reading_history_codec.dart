import 'dart:convert';

import 'reading_history.dart';

/// Converts persisted transcript variants into the two roles rendered by the
/// companion. Stored sender names are historically capitalized by the server.
List<ReadingMessage> readingMessagesFromHistory(dynamic raw, {int limit = 60}) {
  dynamic history = raw;
  if (history is String) {
    try {
      history = jsonDecode(history);
    } catch (_) {
      return const <ReadingMessage>[];
    }
  }

  final entries = switch (history) {
    Map<dynamic, dynamic> value =>
      value.entries
          .map((entry) => (turn: '${entry.key}', value: entry.value))
          .toList()
        ..sort((a, b) => a.turn.compareTo(b.turn)),
    List<dynamic> value => <({String turn, dynamic value})>[
      for (var index = 0; index < value.length; index++)
        (turn: '$index', value: value[index]),
    ],
    _ => <({String turn, dynamic value})>[],
  };

  final messages = <ReadingMessage>[];
  for (final entry in entries) {
    dynamic value = entry.value;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        continue;
      }
    }
    if (value is! Map) continue;
    final sender = '${value['sender'] ?? value['role'] ?? ''}'
        .trim()
        .toLowerCase();
    final role = switch (sender) {
      'agent' || 'assistant' || 'ai' || 'model' => 'assistant',
      'human' || 'user' => 'user',
      _ => null,
    };
    if (role == null) continue;
    final message = value['message'] ?? value['text'] ?? value['content'];
    if (message is! String || message.trim().isEmpty) continue;
    messages.add(ReadingMessage(role, message, turn: entry.turn));
  }
  return messages.length <= limit
      ? messages
      : messages.sublist(messages.length - limit);
}

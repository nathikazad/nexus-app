import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/companion/reading_companion_history.dart';

void main() {
  test('restored messages normalize server sender names for formatting', () {
    final messages = readingMessagesFromHistory(<String, dynamic>{
      '003': <String, dynamic>{
        'sender': 'System',
        'message': 'hidden instructions',
      },
      '002': <String, dynamic>{
        'sender': 'Agent',
        'message': '**Formatted answer**',
      },
      '001': <String, dynamic>{'sender': 'Human', 'message': 'Question'},
    });

    expect(messages.map((message) => message.role), <String>[
      'user',
      'assistant',
    ]);
    expect(messages.last.text, '**Formatted answer**');
  });

  test('restored messages accept JSON and role/text variants', () {
    final messages = readingMessagesFromHistory(
      jsonEncode(<String, dynamic>{
        '001': <String, dynamic>{'role': 'ASSISTANT', 'text': '- one\n- two'},
      }),
    );

    expect(messages.single.role, 'assistant');
    expect(messages.single.text, '- one\n- two');
  });
}

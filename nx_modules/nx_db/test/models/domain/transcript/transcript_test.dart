@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/transcript.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('TR Transcript', () {
    test('TR4.1 TranscriptMessage.fromJson + isFromUser', () {
      final m = TranscriptMessage.fromJson({
        'timestamp': 't1',
        'sender': 'Human',
        'message': 'hi',
      });
      expect(m.timestamp, 't1');
      expect(m.sender, 'Human');
      expect(m.message, 'hi');
      expect(m.isFromUser, true);
      final a = TranscriptMessage.fromJson({
        'timestamp': 't2',
        'sender': 'Agent',
        'message': 'ok',
      });
      expect(a.isFromUser, false);
    });

    test('TR4.2 TranscriptMessage round-trip', () {
      final orig = TranscriptMessage(
        timestamp: 'ts',
        sender: 'Human',
        message: 'm',
      );
      final m = TranscriptMessage.fromJson(orig.toJson());
      expect(m.timestamp, orig.timestamp);
      expect(m.sender, orig.sender);
      expect(m.message, orig.message);
    });

    test('TR4.3 Transcript.fromJson', () {
      final t = Transcript.fromJson({
        'id': 42,
        'messages': {
          '2025-01-01T00:00:00Z': {
            'sender': 'Agent',
            'message': 'hello',
          },
        },
      });
      expect(t.id, 42);
      expect(t.messages.length, 1);
      expect(t.messages['2025-01-01T00:00:00Z']?.message, 'hello');
    });

    test('TR4.4 sortedMessages order', () {
      final t = Transcript.fromJson({
        'id': 1,
        'messages': {
          'b': {'sender': 'Human', 'message': '2'},
          'a': {'sender': 'Human', 'message': '1'},
        },
      });
      final sorted = t.sortedMessages;
      expect(sorted.length, 2);
      expect(sorted.first.message, '1');
      expect(sorted.last.message, '2');
    });

    test('TR4.5 copyWithMessage', () {
      final m1 =
          TranscriptMessage(timestamp: 't1', sender: 'Human', message: 'a');
      var t = Transcript(id: 1, messages: {m1.timestamp: m1});
      final m2 =
          TranscriptMessage(timestamp: 't2', sender: 'Agent', message: 'b');
      t = t.copyWithMessage(m2);
      expect(t.messages.length, 2);
      expect(t.messages.containsKey('t2'), true);
    });
  });
}

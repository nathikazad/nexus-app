import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_people/data/meeting/meeting_transcripts.dart';

List<Map<String, dynamic>> rows(String text) => [
  {'transcript_id': 42, 'text': text, 'status': 'recording'},
];
void main() {
  test(
    'cached text survives offline, reconnects, and ignores older query responses',
    () async {
      final socket = StreamController<List<Map<String, dynamic>>>();
      final request = Completer<List<Map<String, dynamic>>>();
      final saved = <String>[];
      final observed = <MeetingTranscriptState>[];
      final repo = MeetingTranscripts(
        fetch: (_) => request.future,
        subscribe: (_) => socket.stream,
        readCache: (_) async => rows('cached'),
        writeCache: (_, value) async {
          saved.add(value.single['text'] as String);
        },
        refreshInterval: const Duration(days: 1),
      );
      final listener = repo.watch(1).listen(observed.add);
      await Future<void>.delayed(Duration.zero);
      expect(observed.single.rows.single['text'], 'cached');
      expect(observed.single.connected, false);
      socket.add(rows('live'));
      await Future<void>.delayed(Duration.zero);
      request.complete(rows('stale'));
      await Future<void>.delayed(Duration.zero);
      expect(observed.last.rows.single['text'], 'live');
      expect(saved, ['live']);
      socket.addError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(observed.last.connected, false);
      expect(observed.last.rows.single['text'], 'live');
      await listener.cancel();
      await socket.close();
    },
  );
  test(
    'resubscribes after disconnect and stops retrying after disposal',
    () async {
      var connects = 0;
      final sockets = <StreamController<List<Map<String, dynamic>>>>[];
      final observed = <MeetingTranscriptState>[];
      final repo = MeetingTranscripts(
        fetch: (_) async => throw StateError('offline'),
        subscribe: (_) {
          connects++;
          final s = StreamController<List<Map<String, dynamic>>>();
          sockets.add(s);
          return s.stream;
        },
        readCache: (_) async => null,
        writeCache: (_, _) async {},
        retryDelay: const Duration(milliseconds: 5),
        refreshInterval: const Duration(days: 1),
      );
      final listener = repo.watch(1).listen(observed.add);
      await Future<void>.delayed(Duration.zero);
      await sockets.first.close();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(connects, 2);
      sockets.last.add(rows('recovered'));
      await Future<void>.delayed(Duration.zero);
      expect(observed.last.connected, true);
      expect(observed.last.rows.single['text'], 'recovered');
      await listener.cancel();
      await sockets.last.close();
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(connects, 2);
    },
  );
}

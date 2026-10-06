import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_people/data/meeting/meeting_transcripts.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/features/meeting/meeting_detail_page.dart';

void main() {
  testWidgets(
    'meeting shows live text, preserves text offline, then completes',
    (tester) async {
      final stream = StreamController<MeetingTranscriptState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meetingTranscriptsProvider(99).overrideWith((ref) => stream.stream),
          ],
          child: const MaterialApp(
            home: MeetingDetailPage(
              meeting: PersonMeeting(id: 99, name: 'Conversation with Rachel'),
            ),
          ),
        ),
      );
      stream.add(const MeetingTranscriptState([], connected: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('Waiting for recording audio…'), findsOneWidget);
      final rows = [
        {'text': 'Hello Rachel', 'status': 'recording'},
      ];
      stream.add(MeetingTranscriptState(rows, connected: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('Hello Rachel'), findsOneWidget);
      expect(find.text('Recording • transcript in progress'), findsOneWidget);
      stream.add(MeetingTranscriptState(rows));
      await tester.pump();
      await tester.pump();
      expect(find.text('Hello Rachel'), findsOneWidget);
      expect(find.textContaining('Offline or reconnecting'), findsOneWidget);
      stream.add(
        const MeetingTranscriptState([
          {'text': 'Hello Rachel. Nice to meet you.', 'status': 'complete'},
        ], connected: true),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Transcript complete'), findsOneWidget);
      expect(find.text('Hello Rachel. Nice to meet you.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      unawaited(stream.close());
    },
  );
}

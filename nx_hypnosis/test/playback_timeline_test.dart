import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_hypnosis/desires.dart';
import 'package:nx_hypnosis/listening.dart';
import 'package:nx_hypnosis/playback_timeline.dart';
import 'package:nx_hypnosis/timed_story.dart';

Map<String, dynamic> audio() => {
  'link': '/audio',
  'sha256': 'same',
  'duration_seconds': 8,
  'timeline': {
    'version': 1,
    'audio_sha256': 'same',
    'segments': [
      {
        'id': 'a',
        'text': 'First',
        'speaker': 'Roger',
        'start_seconds': .3,
        'end_seconds': 4,
      },
      {
        'id': 'b',
        'text': 'Second',
        'speaker': 'Roger',
        'start_seconds': 4,
        'end_seconds': 8,
      },
    ],
  },
};

class ClockListening extends Listening {
  void move(Tape item, int seconds) {
    tape = item;
    position = Duration(seconds: seconds);
    notifyListeners();
  }
}

void main() {
  test('optional, malformed and stale timelines fall back safely', () {
    expect(PlaybackTimeline.fromAudio(null), isNull);
    expect(PlaybackTimeline.fromAudio({'link': 'a'}), isNull);
    final bad = audio();
    bad['sha256'] = 'different';
    expect(PlaybackTimeline.fromAudio(bad), isNull);
    final overlap = audio();
    overlap['timeline']['segments'][1]['start_seconds'] = 3;
    expect(PlaybackTimeline.fromAudio(overlap), isNull);
    final nan = audio();
    nan['timeline']['segments'][0]['start_seconds'] = double.nan;
    expect(PlaybackTimeline.fromAudio(nan), isNull);
  });
  test('boundaries, pauses, rewind, intro and completion', () {
    final timeline = PlaybackTimeline.fromAudio(audio())!;
    for (final pair in [(0, 0), (3, 0), (4, 1), (8, 1), (20, 1), (1, 0)]) {
      expect(timeline.indexAt(Duration(seconds: pair.$1)), pair.$2);
    }
  });
  testWidgets(
    'follows seeking and repeat; manual pause and resume; ignores other tapes',
    (tester) async {
      final timeline = PlaybackTimeline(
        List.generate(
          30,
          (i) => PlaybackSegment(
            '$i',
            'Line $i\nMore text\nMore text',
            i * 10,
            (i + 1) * 10,
          ),
        ),
      );
      final tape = Tape(
        id: '1',
        desireId: '1',
        title: 'Tape',
        story: 'Edited story',
        audioAsset: 'a',
        audioRevision: 'one',
        timeline: timeline,
      );
      final listening = ClockListening();
      final follow = ValueNotifier(true);
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: TimedStory(
                tape: tape,
                listening: listening,
                follow: follow,
              ),
            ),
          ),
        ),
      );
      listening.move(tape, 200);
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(1000));
      follow.value = false;
      scroll.jumpTo(0);
      listening.move(tape, 210);
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      follow.value = true;
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(1000));
      listening.move(tape, 0);
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      listening.move(
        Tape(id: 'other', desireId: '1', title: 'Other', story: ''),
        250,
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(find.text('Edited story'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      listening.dispose();
      follow.dispose();
      scroll.dispose();
    },
  );
}

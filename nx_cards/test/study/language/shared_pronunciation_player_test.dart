import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/shared_pronunciation_player.dart';

class _Audio implements CardAudioRepository {
  final requests = <String, Completer<Uint8List>>{};
  @override
  Future<Uint8List> fetch(String url) => (requests[url] = Completer()).future;
}

void main() {
  test(
    'slow replay applies speed before playback and normal replay resets it',
    () async {
      final events = <String>[];
      final player = SharedPronunciationPlayer(
        stop: () async {},
        close: () async {},
        setRate: (rate) async {
          events.add('rate $rate');
        },
        play: (_) async {
          events.add('play');
        },
      );
      final audio = _Audio();
      for (final rate in [0.25, 0.5, 1.0]) {
        final request = rate == 1
            ? player.start('test', 'audio', audio)
            : player.start('test', 'audio', audio, rate: rate);
        await Future<void>.delayed(Duration.zero);
        audio.requests['audio']!.complete(Uint8List.fromList([1]));
        await request;
      }
      expect(events, [
        'rate 0.25',
        'play',
        'rate 0.5',
        'play',
        'rate 1.0',
        'play',
      ]);
      player.dispose();
    },
  );

  test(
    'latest tap wins even when the earlier download finishes last',
    () async {
      final events = <String>[];
      final player = SharedPronunciationPlayer(
        stop: () async {
          events.add('stop');
        },
        play: (bytes) async {
          events.add('play ${bytes.single}');
        },
        close: () async {
          events.add('close');
        },
      );
      expect(events, isEmpty);
      final audio = _Audio();
      final first = player.start('first', 'a', audio);
      await Future<void>.delayed(Duration.zero);
      final second = player.start('second', 'b', audio);
      await Future<void>.delayed(Duration.zero);
      audio.requests['b']!.complete(Uint8List.fromList([2]));
      await second;
      audio.requests['a']!.complete(Uint8List.fromList([1]));
      await first;
      expect(events, ['stop', 'stop', 'play 2']);
      expect(player.owner, 'second');
      expect(player.playing, isTrue);
      final third = player.start('third', 'c', audio);
      await Future<void>.delayed(Duration.zero);
      expect(events.last, 'stop');
      expect(player.playing, isFalse);
      audio.requests['c']!.complete(Uint8List.fromList([3]));
      await third;
      expect(events.last, 'play 3');
      player.completed();
      expect(player.playing, isFalse);
      player.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(events.last, 'close');
    },
  );
}

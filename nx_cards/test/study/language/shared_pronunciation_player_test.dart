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

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nx_hypnosis/desires.dart';
import 'package:nx_hypnosis/listening.dart';

class Player extends Fake implements AudioPlayer {
  final calls = <String>[];
  bool fail = false;
  @override
  Duration? get duration => const Duration(seconds: 100);
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<Duration?> setAsset(
    String path, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) async {
    if (fail) throw StateError('offline');
    calls.add('load');
    return duration;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    calls.add('seek:${position!.inSeconds}');
  }

  @override
  Future<void> setSpeed(double speed) async {
    calls.add('speed:$speed');
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {
    calls.add('loop:$mode');
  }

  @override
  Future<void> play() async {
    calls.add('play');
  }
}

class ListeningWithPlayer extends Listening {
  final audio = Player();
  @override
  AudioPlayer get player => audio;
}

void main() {
  test(
    'restored recording loads, applies settings and seeks before playing',
    () async {
      final listening = ListeningWithPlayer();
      final tape = Tape(
        id: '12',
        desireId: '1',
        title: 'Test',
        story: '',
        audioAsset: 'test.mp3',
      );
      listening.restore(
        tape,
        position: const Duration(seconds: 42),
        speed: 1.25,
        repeat: true,
      );
      expect(listening.audio.calls, isEmpty);
      await listening.open(tape);
      expect(listening.audio.calls, [
        'stop',
        'load',
        'speed:1.25',
        'loop:LoopMode.one',
        'seek:42',
        'play',
      ]);
      listening.dispose();
    },
  );
  test(
    'failed load retains checkpoint for retry and clamps to recording length',
    () async {
      final listening = ListeningWithPlayer();
      final tape = Tape(
        id: '12',
        desireId: '1',
        title: 'Test',
        story: '',
        audioAsset: 'test.mp3',
      );
      listening.restore(
        tape,
        position: const Duration(seconds: 150),
        speed: 1,
        repeat: false,
      );
      listening.audio.fail = true;
      await listening.open(tape);
      expect(listening.position.inSeconds, 150);
      expect(listening.tape, tape);
      listening.audio.fail = false;
      await listening.open(tape);
      expect(listening.audio.calls, contains('seek:100'));
      expect(listening.audio.calls.last, 'play');
      listening.dispose();
    },
  );
}

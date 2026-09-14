import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nx_hypnosis/listening.dart';
import 'package:nx_hypnosis/desires.dart';

class FakePlayer extends Fake implements AudioPlayer {
  final modes = <LoopMode>[];
  bool fail = false;
  @override
  Future<void> setLoopMode(LoopMode mode) async {
    if (fail) throw StateError('Unavailable');
    modes.add(mode);
  }
}

class TestListening extends Listening {
  final fakePlayer = FakePlayer();
  @override
  AudioPlayer get player => fakePlayer;
}

void main() {
  testWidgets('repeat button toggles on a narrow player without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final listening = TestListening()
      ..tape = Tape(
        id: 'test',
        desireId: 'wealth',
        title: 'Affirmation',
        story: 'Text',
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(bottomNavigationBar: ListeningBar(listening: listening)),
      ),
    );
    await tester.tap(find.byTooltip('Turn auto repeat on'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Turn auto repeat off'), findsOneWidget);
    expect(listening.fakePlayer.modes, [LoopMode.one]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    listening.dispose();
  });
  test('repeat uses the audio engine loop and can be disabled', () async {
    final listening = TestListening();
    await listening.toggleRepeat();
    expect(listening.repeatEnabled, isTrue);
    await listening.toggleRepeat();
    expect(listening.repeatEnabled, isFalse);
    expect(listening.fakePlayer.modes, [LoopMode.one, LoopMode.off]);
    listening.dispose();
  });
  test('failed repeat change preserves previous state', () async {
    final listening = TestListening();
    listening.fakePlayer.fail = true;
    await listening.toggleRepeat();
    expect(listening.repeatEnabled, isFalse);
    expect(listening.changingRepeat, isFalse);
    expect(listening.error, isNotNull);
    listening.dispose();
  });
}

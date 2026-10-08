import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/features/hardware/widgets/audio_section.dart';

void main() {
  List<int> status(int live, int background, int seconds) {
    final b = List<int>.filled(18, 0);
    b[17] = 1;
    b[16] = live;
    b[1] = background;
    for (var i = 0; i < 4; i++) {
      b[12 + i] = (seconds >> (8 * i)) & 255;
    }
    return b;
  }

  test('status rejects old firmware and decodes device elapsed time', () {
    expect(() => NecklaceAudioStatus([0]), throwsFormatException);
    expect(NecklaceAudioStatus(status(2, 2, 125)).elapsed, '2:05');
  });
  testWidgets('observed recordings can both stop independently',
      (tester) async {
    final commands = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AudioSection(
                isConnected: true,
                readStatus: () async => status(2, 2, 125),
                command: (n) async {
                  commands.add(n);
                  return true;
                }))));
    await tester.pump();
    expect(find.text('Recording · 2:05'), findsOneWidget);
    await tester.tap(find.text('Stop & send'));
    await tester.pump();
    await tester.tap(find.text('Stop recording'));
    await tester.pump();
    expect(commands, [3, 0]);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'idle start actions are distinct and disconnected state is unavailable',
      (tester) async {
    final commands = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AudioSection(
                isConnected: true,
                readStatus: () async => status(1, 0, 0),
                command: (n) async {
                  commands.add(n);
                  return true;
                }))));
    await tester.pump();
    await tester.tap(find.text('Talk through necklace'));
    await tester.pump();
    await tester.tap(find.text('Start recording'));
    await tester.pump();
    expect(commands, [4, 1]);
    await tester.pumpWidget(const SizedBox());
  });
}

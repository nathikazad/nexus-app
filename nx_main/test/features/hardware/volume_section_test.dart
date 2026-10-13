import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/features/hardware/volume_section.dart';

void main() {
  testWidgets(
      'two controls read device values, write only selected output, show pending',
      (tester) async {
    final values = [2, 30, 65, 0, 3, 1, 0];
    final writes = <List<int>>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VolumeSection(
                isConnected: true,
                read: () async => List.of(values),
                write: (output, percent) async {
                  writes.add([output, percent]);
                  values[output + 1] = percent;
                  values[3] = 1;
                  return true;
                }))));
    await tester.pump();
    expect(find.text('Headset connected: Both'), findsOneWidget);
    expect(find.text('Ready for audio: Left'), findsOneWidget);
    expect(find.text('Speaker: 30%'), findsOneWidget);
    expect(find.text('Headset: 65%'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider).last);
    slider.onChangeStart!(20);
    slider.onChanged!(20);
    slider.onChangeEnd!(20);
    await tester.pump();
    await tester.pump();
    expect(writes, [
      [1, 20]
    ]);
    expect(values[1], 30);
    expect(find.text('Applied; saving after audio finishes…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

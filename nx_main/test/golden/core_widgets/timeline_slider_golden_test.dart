import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/core/widgets/timeline_slider.dart';

void main() {
  testWidgets('TimelineSlider matches golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: TimelineSlider(
                value: 120,
                minTime: 60,
                maxTime: 180,
                marks: const [60, 120, 180],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(TimelineSlider),
      matchesGoldenFile('goldens/timeline_slider.png'),
    );
  });
}

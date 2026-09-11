import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/study/language/drawing/script_drawing_canvas.dart';

void main() {
  testWidgets(
    'vertical strokes draw while gestures outside the canvas scroll',
    (tester) async {
      final drawing = ScriptDrawingController();
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  const SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: Text('Prompt'),
                  ),
                  SizedBox(
                    height: 250,
                    child: ScriptDrawingCanvas(
                      controller: drawing,
                      semanticsLabel: 'Write',
                    ),
                  ),
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        ),
      );
      final area = find.byKey(const ValueKey('script-drawing-canvas'));
      await tester.drag(area, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(
        drawing.strokes.single.last.dy - drawing.strokes.single.first.dy,
        lessThan(-100),
      );
      await tester.dragFrom(const Offset(100, 80), const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(drawing.strokes, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      drawing.dispose();
      scroll.dispose();
    },
  );
}

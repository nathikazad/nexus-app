import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_canvas/canvas/canvas_controller.dart';
import 'package:nx_canvas/canvas/canvas_surface.dart';
import 'package:nx_canvas/canvas/drawing.dart';

void main() {
  testWidgets(
    'pen samples repaint only live ink, leaving scene and shell cached',
    (tester) async {
      final c = CanvasController(
        Drawing(
          strokes: [
            InkStroke(
              id: 'existing',
              points: const [Dot(10, 10), Dot(100, 100)],
              color: 0xff000000,
              width: 3,
            ),
          ],
        ),
      );
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              builds++;
              return CanvasSurface(controller: c);
            },
          ),
        ),
      );
      c.begin(const Dot(200, 200));
      await tester.pump();
      final before = builds;
      final scene = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('canvas-scene-layer')),
      );
      final ink = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('canvas-ink-layer')),
      );
      for (var i = 1; i <= 100; i++) {
        c.update(Dot(200 + i.toDouble(), 200));
      }
      expect(scene.debugNeedsPaint, isFalse);
      expect(ink.debugNeedsPaint, isTrue);
      await tester.pump();
      expect(builds, before);
      c.end();
      expect(scene.debugNeedsPaint, isTrue);
      await tester.pump();
      expect(c.strokes.length, 2);
      expect(builds, greaterThan(before));
    },
  );

  testWidgets('stylus draws, finger pans, palm is ignored, cancel drops ink', (
    tester,
  ) async {
    final c = CanvasController(Drawing());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CanvasSurface(controller: c)),
      ),
    );
    final pen = await tester.startGesture(
      const Offset(100, 100),
      kind: PointerDeviceKind.stylus,
      pointer: 1,
    );
    await pen.moveTo(const Offset(200, 100));
    final palm = await tester.startGesture(
      const Offset(250, 250),
      kind: PointerDeviceKind.touch,
      pointer: 2,
    );
    await palm.moveBy(const Offset(100, 100));
    expect(c.view.x, 0);
    await palm.up();
    await pen.up();
    expect(c.strokes.length, 1);
    final finger = await tester.startGesture(
      const Offset(100, 200),
      pointer: 3,
    );
    await finger.moveBy(const Offset(80, 40));
    await finger.up();
    expect(c.view.x, 80);
    expect(c.view.y, 40);
    expect(c.strokes.length, 1);
    final cancelled = await tester.startGesture(
      const Offset(300, 200),
      kind: PointerDeviceKind.stylus,
      pointer: 4,
    );
    await cancelled.moveBy(const Offset(50, 20));
    await cancelled.cancel();
    expect(c.strokes.length, 1);
    c.back();
    expect(c.view.x, 0);
  });
  testWidgets('two fingers zoom around their midpoint without drawing', (
    tester,
  ) async {
    final c = CanvasController(Drawing());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CanvasSurface(controller: c)),
      ),
    );
    final first = await tester.startGesture(const Offset(100, 200), pointer: 1);
    final second = await tester.startGesture(
      const Offset(300, 200),
      pointer: 2,
    );
    await first.moveTo(const Offset(50, 200));
    await second.moveTo(const Offset(350, 200));
    expect(c.view.scale, closeTo(1.5, .001));
    expect(c.view.toWorld(const Dot(200, 200)).x, closeTo(200, .001));
    await first.up();
    await second.up();
    expect(c.strokes, isEmpty);
  });
}

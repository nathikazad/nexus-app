import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_canvas/canvas/canvas_controller.dart';
import 'package:nx_canvas/canvas/drawing.dart';

const box = [Dot(40, -20), Dot(60, -20), Dot(60, 20), Dot(40, 20)];
InkStroke stroke(List<Dot> points) =>
    InkStroke(id: 'ink', points: points, color: 0xff283d44, width: 3);

void main() {
  test('region cuts sparse crossing ink and interpolates pressure', () {
    final ink = stroke(const [Dot(0, 0, .2), Dot(100, 0, .8)]);
    final pieces = eraseRegion(ink, box);
    expect(pieces, hasLength(2));
    expect(pieces.first.points.last.x, closeTo(40, 1e-8));
    expect(pieces.last.points.first.x, closeTo(60, 1e-8));
    expect(pieces.first.points.last.pressure, closeTo(.44, 1e-8));
    expect(pieces.map((s) => s.id).toSet(), hasLength(2));
    final copy = Drawing.fromJson(
      jsonDecode(jsonEncode(Drawing(strokes: pieces).toJson())),
    );
    expect(copy.toJson(), Drawing(strokes: pieces).toJson());
  });
  test(
    'region removes contained ink and boundary dots; leaves misses intact',
    () {
      expect(eraseRegion(stroke(const [Dot(50, 0)]), box), isEmpty);
      expect(eraseRegion(stroke(const [Dot(40, 0)]), box), isEmpty);
      expect(eraseRegion(stroke(const [Dot(45, 0), Dot(55, 0)]), box), isEmpty);
      final outside = stroke(const [Dot(0, 30), Dot(100, 30)]);
      expect(eraseRegion(outside, box).single, same(outside));
      expect(
        eraseRegion(outside, const [
          Dot(0, 30),
          Dot(50, 30),
          Dot(100, 30),
        ]).single,
        same(outside),
      );
    },
  );
  test('concave region preserves ink through its open notch', () {
    const u = [
      Dot(20, -20),
      Dot(80, -20),
      Dot(80, 20),
      Dot(60, 20),
      Dot(60, -10),
      Dot(40, -10),
      Dot(40, 20),
      Dot(20, 20),
    ];
    final parts = eraseRegion(stroke(const [Dot(0, 0), Dot(100, 0)]), u);
    expect(parts, hasLength(3));
    expect(parts[1].points.first.x, closeTo(40, 1e-8));
    expect(parts[1].points.last.x, closeTo(60, 1e-8));
  });
  test(
    'region commits on lift, closes automatically, undoes once, and cancels',
    () {
      final ink = stroke(const [Dot(0, 0), Dot(100, 0)]);
      final c = CanvasController(
        Drawing(strokes: [ink], view: const CanvasView(scale: 2, x: 90)),
      );
      c.setTool(CanvasTool.regionEraser);
      c.begin(box.first);
      for (final p in box.skip(1)) {
        c.update(p);
      }
      expect(c.strokes.single, same(ink));
      expect(c.revision, 0);
      c.end();
      expect(c.strokes, hasLength(2));
      expect(c.selected, isEmpty);
      expect(c.revision, 1);
      c.undo();
      expect(c.strokes.single, same(ink));
      expect(c.view.scale, 2);
      c.redo();
      expect(c.strokes, hasLength(2));
      final before = c.strokes;
      c.begin(box.first);
      for (final p in box.skip(1)) {
        c.update(p);
      }
      c.cancel();
      expect(c.strokes, same(before));
      expect(c.lasso, isEmpty);
      c.dispose();
    },
  );
}

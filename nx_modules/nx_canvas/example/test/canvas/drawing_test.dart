import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_canvas/canvas/canvas_controller.dart';
import 'package:nx_canvas/canvas/drawing.dart';

InkStroke line() => InkStroke(
  id: 'line',
  points: const [Dot(0, 0), Dot(100, 0)],
  color: 0xff283d44,
  width: 2,
);
void main() {
  test(
    'native journal recovery after database reopen imports exactly once',
    () {
      final first = CanvasController(Drawing());
      first.addNativeStroke(
        const [Dot(10, 20), Dot(30, 40)],
        color: 0xff000000,
        width: 3,
        sourceId: 'journal-record',
      );
      final reopened = CanvasController(
        Drawing.fromJson(jsonDecode(jsonEncode(first.drawing.toJson()))),
      );
      reopened.addNativeStroke(
        const [Dot(10, 20), Dot(30, 40)],
        color: 0xff000000,
        width: 3,
        sourceId: 'journal-record',
      );
      expect(reopened.strokes, hasLength(1));
      expect(reopened.revision, 0);
      first.dispose();
      reopened.dispose();
    },
  );

  test(
    'native teardown redelivery does not duplicate or resurrect undone ink',
    () {
      final c = CanvasController(Drawing());
      void deliver() => c.addNativeStroke(
        const [Dot(5, 10), Dot(25, 40)],
        color: 0xff000000,
        width: 3,
        sourceId: 'completed-record-1',
      );
      deliver();
      deliver();
      expect(c.strokes, hasLength(1));
      expect(c.revision, 1);
      c.undo();
      deliver();
      expect(c.strokes, isEmpty);
      c.redo();
      expect(c.strokes, hasLength(1));
      c.dispose();
      expect(deliver, returnsNormally);
    },
  );

  test('native stroke remains editable, serializable, and undoable', () {
    final c = CanvasController(Drawing());
    c.addNativeStroke(
      const [Dot(-100, 50, .4), Dot(100, 50, .8)],
      color: 0xff168274,
      width: 3,
    );
    final restored = CanvasController(
      Drawing.fromJson(jsonDecode(jsonEncode(c.drawing.toJson()))),
    );
    expect(restored.strokes.single.points.first.pressure, .4);
    expect(restored.strokes.single.color, 0xff168274);
    restored.setTool(CanvasTool.eraser);
    restored.begin(const Dot(0, 50));
    restored.end();
    expect(restored.strokes.length, 2);
    restored.undo();
    expect(restored.strokes.length, 1);
    c.undo();
    expect(c.strokes, isEmpty);
    c.redo();
    expect(c.strokes.single.width, 3);
  });

  test('partial erasing splits sparse segments at disk intersections', () {
    final pieces = eraseDisk(line(), const Dot(50, 0), 9);
    expect(pieces, hasLength(2));
    expect(pieces.first.points.last.x, closeTo(40, .001));
    expect(pieces.last.points.first.x, closeTo(60, .001));
    expect(pieces.map((s) => s.id).toSet(), hasLength(2));
  });
  test('eraser misses preserve strokes, dots erase, full coverage removes', () {
    final s = line();
    expect(eraseDisk(s, const Dot(50, 100), 5).single, same(s));
    expect(eraseDisk(s, const Dot(50, 0), 100), isEmpty);
    expect(
      eraseDisk(s.withPoints(const [Dot(20, 20)]), const Dot(20, 20), 5),
      isEmpty,
    );
  });
  test('fast erase gesture cuts crossed strokes and undoes as one action', () {
    final c = CanvasController(Drawing(strokes: [line()]));
    c.setTool(CanvasTool.eraser);
    c.begin(const Dot(50, -100));
    c.update(const Dot(50, 100));
    c.end();
    expect(c.strokes.length, 2);
    c.undo();
    expect(c.strokes.single.points.last.x, 100);
    c.redo();
    expect(c.strokes.length, 2);
  });
  test('lasso moves selected ink only and undo preserves navigation', () {
    final c = CanvasController(
      Drawing(
        strokes: [
          line(),
          line().withPoints(const [Dot(200, 200)], id: 'other'),
        ],
      ),
    );
    c.setTool(CanvasTool.select);
    c.begin(const Dot(-10, -10));
    c.update(const Dot(110, -10));
    c.update(const Dot(110, 10));
    c.update(const Dot(-10, 10));
    c.end();
    expect(c.selected, {'line'});
    c.begin(const Dot(50, 0));
    c.update(const Dot(70, 20));
    c.end();
    expect(c.strokes.first.points.first.x, 20);
    expect(c.strokes.last.points.first.x, 200);
    c.zoom(2, const Dot(100, 100));
    c.undo();
    expect(c.strokes.first.points.first.x, 0);
    expect(c.view.scale, 2);
    c.back();
    expect(c.view.scale, 1);
  });
  test('versioned format round trips ink, pressure, view and named places', () {
    final drawing = Drawing(
      strokes: [line()],
      view: const CanvasView(x: -500, y: 260, scale: .7),
      places: const [SavedPlace('Opening', CanvasView(x: 5))],
    );
    final copy = Drawing.fromJson(jsonDecode(jsonEncode(drawing.toJson())));
    expect(copy.toJson(), drawing.toJson());
    expect(
      () => Drawing.fromJson({...drawing.toJson(), 'version': 999}),
      throwsFormatException,
    );
  });
}

import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_canvas_core/drawing.dart';
import 'package:nx_docs/documents/editor/canvas_preview_pages.dart';

void main() {
  InkStroke stroke(String id, List<Dot> points) =>
      InkStroke(id: id, points: points, color: 0xff000000, width: 3);
  test('pages are ordered row then column and skip unpopulated gaps', () {
    final pages = canvasPreviewPages(
      Drawing(
        boards: {'width': 100, 'height': 200},
        strokes: [
          stroke('bottom', [const Dot(10, 210)]),
          stroke('right', [const Dot(210, 10)]),
          stroke('left', [const Dot(-10, 10)]),
        ],
      ),
    );
    expect(pages, [
      const Rect.fromLTWH(-100, 0, 100, 200),
      const Rect.fromLTWH(200, 0, 100, 200),
      const Rect.fromLTWH(0, 200, 100, 200),
    ]);
  });
  test('sparse strokes include pages crossed between samples', () {
    final pages = canvasPreviewPages(
      Drawing(
        boards: {'width': 100, 'height': 200},
        strokes: [
          stroke('across', [const Dot(10, 10), const Dot(210, 10)]),
        ],
      ),
    );
    expect(pages.length, 3);
  });
}

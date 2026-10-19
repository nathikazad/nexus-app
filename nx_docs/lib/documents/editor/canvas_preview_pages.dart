import 'dart:math' as math;
import 'dart:ui';
import 'package:nx_canvas_core/drawing.dart';

/// Populated sheets, in reading order. Empty gaps do not become blank pages.
List<Rect> canvasPreviewPages(Drawing drawing) {
  final width = (drawing.boards?['width'] as num?)?.toDouble();
  final height = (drawing.boards?['height'] as num?)?.toDouble();
  if (width == null ||
      height == null ||
      !width.isFinite ||
      !height.isFinite ||
      width <= 0 ||
      height <= 0) {
    return [];
  }
  final cells = <(int, int)>{};
  void add(Dot point) =>
      cells.add(((point.x / width).floor(), (point.y / height).floor()));
  for (final stroke in drawing.strokes) {
    if (stroke.points.length == 1) add(stroke.points.first);
    for (var i = 1; i < stroke.points.length; i++) {
      final a = stroke.points[i - 1], b = stroke.points[i];
      final cuts = <double>[0, 1];
      void boundaries(double start, double end, double step) {
        if (start == end) return;
        for (
          var n = (math.min(start, end) / step).floor() + 1;
          n < (math.max(start, end) / step).ceil();
          n++
        ) {
          cuts.add((n * step - start) / (end - start));
        }
      }

      boundaries(a.x, b.x, width);
      boundaries(a.y, b.y, height);
      cuts.sort();
      for (var j = 1; j < cuts.length; j++) {
        add(a.lerp(b, (cuts[j - 1] + cuts[j]) / 2));
      }
    }
  }
  if (cells.isEmpty) cells.add((0, 0));
  final ordered = cells.toList()
    ..sort(
      (a, b) => a.$2 == b.$2 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
    );
  return [
    for (final cell in ordered)
      Rect.fromLTWH(cell.$1 * width, cell.$2 * height, width, height),
  ];
}

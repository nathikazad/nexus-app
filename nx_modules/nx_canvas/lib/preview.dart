import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'drawing.dart';

void paintStroke(Canvas canvas, InkStroke stroke) {
  paintPoints(canvas, stroke.points, stroke.color, stroke.width);
}

void paintPoints(Canvas canvas, List<Dot> points, int color, double width) {
  if (points.isEmpty) return;
  final paint = Paint()
    ..color = Color(color)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  if (points.length == 1) {
    canvas.drawCircle(
      Offset(points.first.x, points.first.y),
      width / 2,
      paint..style = PaintingStyle.fill,
    );
  }
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1], b = points[i];
    paint.strokeWidth = width * (.5 + (a.pressure + b.pressure) / 4);
    canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
  }
}

Future<Uint8List> renderPreview(Drawing drawing) async {
  const size = Size(640, 400);
  final recorder = ui.PictureRecorder();
  // Keep the actual recording independent of the interactive widget tree.
  final output = Canvas(recorder);
  output.drawColor(const Color(0xfff8f8f3), BlendMode.src);
  final points = drawing.strokes.expand((s) => s.points).toList();
  if (points.isNotEmpty) {
    final minX = points.map((p) => p.x).reduce(math.min),
        maxX = points.map((p) => p.x).reduce(math.max);
    final minY = points.map((p) => p.y).reduce(math.min),
        maxY = points.map((p) => p.y).reduce(math.max);
    final scale = math
        .min(600 / math.max(1, maxX - minX), 360 / math.max(1, maxY - minY))
        .clamp(.001, 2.0);
    output.translate(
      size.width / 2 - (minX + maxX) / 2 * scale,
      size.height / 2 - (minY + maxY) / 2 * scale,
    );
    output.scale(scale);
    for (final stroke in drawing.strokes) {
      paintStroke(output, stroke);
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(640, 400);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

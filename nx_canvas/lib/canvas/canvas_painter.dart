import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'canvas_controller.dart';
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

class CanvasPainter extends CustomPainter {
  CanvasPainter(this.controller, {this.overlay = false})
    : super(repaint: overlay ? controller.inkRepaint : controller.sceneRepaint);
  final bool overlay;
  final CanvasController controller;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final view = controller.view;
    if (!overlay) {
      canvas.drawColor(const Color(0xfff8f8f3), BlendMode.src);
      var spacing = 32 * view.scale;
      while (spacing < 18) {
        spacing *= 4;
      }
      while (spacing > 100) {
        spacing /= 4;
      }
      final grid = Paint()..color = const Color(0xffd7dfd9);
      for (var x = view.x % spacing; x < size.width; x += spacing) {
        for (var y = view.y % spacing; y < size.height; y += spacing) {
          canvas.drawCircle(Offset(x, y), .8, grid);
        }
      }
    }
    canvas.save();
    canvas.translate(view.x, view.y);
    canvas.scale(view.scale);
    if (!overlay) {
      for (final stroke in controller.strokes) {
        paintStroke(canvas, stroke);
      }
      canvas.restore();
      return;
    }
    if (controller.livePoints.isNotEmpty) {
      paintPoints(
        canvas,
        controller.livePoints,
        controller.color,
        controller.width,
      );
    }

    final selected = controller.strokes
        .where((s) => controller.selected.contains(s.id))
        .expand((s) => s.points)
        .toList();
    if (selected.isNotEmpty) {
      final rect = Rect.fromLTRB(
        selected.map((p) => p.x).reduce(math.min),
        selected.map((p) => p.y).reduce(math.min),
        selected.map((p) => p.x).reduce(math.max),
        selected.map((p) => p.y).reduce(math.max),
      ).inflate(10 / view.scale);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(5 / view.scale)),
        Paint()
          ..color = const Color(0xff168274)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / view.scale,
      );
    }
    if (controller.lasso.isNotEmpty) {
      final path = Path()
        ..moveTo(controller.lasso.first.x, controller.lasso.first.y);
      for (final p in controller.lasso.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      path.close();
      final regionErase = controller.tool == CanvasTool.regionEraser;
      canvas.drawPath(
        path,
        Paint()
          ..color = (regionErase
              ? const Color(0x25c13c32)
              : const Color(0x15168274)),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = regionErase
              ? const Color(0xffc13c32)
              : const Color(0xff168274)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / view.scale,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) =>
      oldDelegate.controller != controller || oldDelegate.overlay != overlay;
}

/// A replaceable thumbnail, never the editable source of truth.
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

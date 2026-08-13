import 'package:flutter/material.dart';
import 'package:nx_cards/app/theme.dart';

class ScriptDrawingController extends ChangeNotifier {
  final List<List<Offset>> _strokes = <List<Offset>>[];

  bool get hasStrokes => _strokes.isNotEmpty;
  List<List<Offset>> get strokes => _strokes;

  void startStroke(Offset point) {
    _strokes.add(<Offset>[point]);
    notifyListeners();
  }

  void extendStroke(Offset point) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(point);
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    notifyListeners();
  }
}

class ScriptDrawingCanvas extends StatelessWidget {
  const ScriptDrawingCanvas({
    super.key,
    required this.controller,
    required this.semanticsLabel,
  });

  final ScriptDrawingController controller;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        key: const ValueKey<String>('script-drawing-canvas'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => controller.startStroke(details.localPosition),
        onPanUpdate: (details) =>
            controller.extendStroke(details.localPosition),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => CustomPaint(
            key: const ValueKey<String>('script-drawing-paint'),
            foregroundPainter: _StrokePainter(controller.strokes),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: RecallColors.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ),
  );
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RecallColors.ink
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawLine(
          stroke.first,
          stroke.first + const Offset(0.01, 0.01),
          paint,
        );
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}

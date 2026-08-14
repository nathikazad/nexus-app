part of 'nx_appflowy_blocks.dart';

class _ExcalidrawPreview extends StatelessWidget {
  const _ExcalidrawPreview({required this.scene});

  final Map<String, dynamic> scene;

  @override
  Widget build(BuildContext context) {
    final elements = _excalidrawVisibleElements(scene);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(
            painter: _ExcalidrawPreviewPainter(
              elements: elements,
              backgroundColor: _excalidrawBackgroundColor(scene),
            ),
            child: const SizedBox.expand(),
          ),
          if (elements.isEmpty)
            Center(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xeefbfbfb),
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    'Click Open to draw',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExcalidrawPreviewPainter extends CustomPainter {
  const _ExcalidrawPreviewPainter({
    required this.elements,
    required this.backgroundColor,
  });

  final List<Map<String, dynamic>> elements;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = backgroundColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)),
      background,
    );

    if (elements.isEmpty) {
      final stroke = Paint()
        ..color = AppColors.muted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final center = size.center(Offset.zero);
      canvas.drawCircle(center, 22, stroke);
      canvas.drawLine(
        center.translate(-34, 28),
        center.translate(34, -28),
        stroke,
      );
      return;
    }

    final sceneBounds = _sceneBounds(elements);
    if (sceneBounds == null || sceneBounds.isEmpty) {
      return;
    }
    final viewport = Rect.fromLTWH(18, 18, size.width - 36, size.height - 36);
    final paddedBounds = sceneBounds.inflate(32);
    final scale = math.min(
      viewport.width / math.max(paddedBounds.width, 1),
      viewport.height / math.max(paddedBounds.height, 1),
    );
    final dx =
        viewport.left +
        (viewport.width - paddedBounds.width * scale) / 2 -
        paddedBounds.left * scale;
    final dy =
        viewport.top +
        (viewport.height - paddedBounds.height * scale) / 2 -
        paddedBounds.top * scale;

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)),
    );
    canvas.translate(dx, dy);
    canvas.scale(scale);
    for (final element in elements) {
      _drawElement(canvas, element);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ExcalidrawPreviewPainter oldDelegate) {
    return oldDelegate.elements != elements ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

void _drawElement(Canvas canvas, Map<String, dynamic> element) {
  final type = element['type'];
  final bounds = _elementBounds(element);
  if (bounds == null) {
    return;
  }

  canvas.save();
  final angle = _doubleAttribute(element, 'angle');
  if (angle != 0) {
    final center = bounds.center;
    canvas
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..translate(-center.dx, -center.dy);
  }

  switch (type) {
    case 'rectangle':
      _drawRectangle(canvas, element, bounds);
    case 'ellipse':
      _drawEllipse(canvas, element, bounds);
    case 'diamond':
      _drawDiamond(canvas, element, bounds);
    case 'arrow':
      _drawLineElement(canvas, element, arrow: true);
    case 'line':
      _drawLineElement(canvas, element, arrow: false);
    case 'freedraw':
      _drawLineElement(canvas, element, arrow: false);
    case 'text':
      _drawTextElement(canvas, element);
    default:
      _drawRectangle(canvas, element, bounds);
  }

  canvas.restore();
}

void _drawRectangle(Canvas canvas, Map<String, dynamic> element, Rect bounds) {
  final fill = _fillPaint(element);
  final stroke = _strokePaint(element);
  final radius = Radius.circular(math.min(bounds.shortestSide / 6, 12));
  final rrect = RRect.fromRectAndRadius(bounds, radius);
  if (fill != null) {
    canvas.drawRRect(rrect, fill);
  }
  canvas.drawRRect(rrect, stroke);
}

void _drawEllipse(Canvas canvas, Map<String, dynamic> element, Rect bounds) {
  final fill = _fillPaint(element);
  final stroke = _strokePaint(element);
  if (fill != null) {
    canvas.drawOval(bounds, fill);
  }
  canvas.drawOval(bounds, stroke);
}

void _drawDiamond(Canvas canvas, Map<String, dynamic> element, Rect bounds) {
  final path = ui.Path()
    ..moveTo(bounds.center.dx, bounds.top)
    ..lineTo(bounds.right, bounds.center.dy)
    ..lineTo(bounds.center.dx, bounds.bottom)
    ..lineTo(bounds.left, bounds.center.dy)
    ..close();
  final fill = _fillPaint(element);
  if (fill != null) {
    canvas.drawPath(path, fill);
  }
  canvas.drawPath(path, _strokePaint(element));
}

void _drawLineElement(
  Canvas canvas,
  Map<String, dynamic> element, {
  required bool arrow,
}) {
  final points = _elementPoints(element);
  if (points.length < 2) {
    return;
  }
  final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }
  final stroke = _strokePaint(element)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(path, stroke);
  if (arrow) {
    _drawArrowHead(canvas, points, stroke);
  }
}

void _drawArrowHead(Canvas canvas, List<Offset> points, Paint stroke) {
  final end = points.last;
  var previous = points[points.length - 2];
  for (var i = points.length - 2; i >= 0; i--) {
    if ((end - points[i]).distance > 0.1) {
      previous = points[i];
      break;
    }
  }
  final angle = math.atan2(end.dy - previous.dy, end.dx - previous.dx);
  final length = math.max(12.0, stroke.strokeWidth * 4);
  const spread = math.pi / 7;
  final left = Offset(
    end.dx - length * math.cos(angle - spread),
    end.dy - length * math.sin(angle - spread),
  );
  final right = Offset(
    end.dx - length * math.cos(angle + spread),
    end.dy - length * math.sin(angle + spread),
  );
  canvas
    ..drawLine(end, left, stroke)
    ..drawLine(end, right, stroke);
}

void _drawTextElement(Canvas canvas, Map<String, dynamic> element) {
  final text = element['text'];
  if (text is! String || text.isEmpty) {
    return;
  }
  final x = _doubleAttribute(element, 'x');
  final y = _doubleAttribute(element, 'y');
  final width = _doubleAttribute(element, 'width', fallback: 220);
  final fontSize = _doubleAttribute(element, 'fontSize', fallback: 20);
  final color = _elementColor(element['strokeColor'], _excalidrawStrokeColor);
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0,
      ),
    ),
    maxLines: 6,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: math.max(width, fontSize * 2));
  painter.paint(canvas, Offset(x, y));
}

Paint _strokePaint(Map<String, dynamic> element) {
  final opacity = _doubleAttribute(element, 'opacity', fallback: 100) / 100;
  return Paint()
    ..color = _elementColor(
      element['strokeColor'],
      _excalidrawStrokeColor,
    ).withValues(alpha: opacity.clamp(0, 1))
    ..style = PaintingStyle.stroke
    ..strokeWidth = _doubleAttribute(element, 'strokeWidth', fallback: 2);
}

Paint? _fillPaint(Map<String, dynamic> element) {
  final background = element['backgroundColor'];
  if (background is! String ||
      background == 'transparent' ||
      background.trim().isEmpty) {
    return null;
  }
  final opacity = _doubleAttribute(element, 'opacity', fallback: 100) / 100;
  return Paint()
    ..color = _elementColor(
      background,
      Colors.transparent,
    ).withValues(alpha: opacity.clamp(0, 1))
    ..style = PaintingStyle.fill;
}

Rect? _sceneBounds(List<Map<String, dynamic>> elements) {
  Rect? bounds;
  for (final element in elements) {
    final elementBounds = _elementBounds(element);
    if (elementBounds == null) {
      continue;
    }
    bounds = bounds == null
        ? elementBounds
        : bounds.expandToInclude(elementBounds);
  }
  return bounds;
}

Rect? _elementBounds(Map<String, dynamic> element) {
  final type = element['type'];
  if (type == 'arrow' || type == 'line' || type == 'freedraw') {
    final points = _elementPoints(element);
    if (points.isEmpty) {
      return null;
    }
    var left = points.first.dx;
    var right = points.first.dx;
    var top = points.first.dy;
    var bottom = points.first.dy;
    for (final point in points.skip(1)) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(
      left,
      top,
      right,
      bottom,
    ).inflate(_doubleAttribute(element, 'strokeWidth', fallback: 2) + 8);
  }

  final x = _doubleAttribute(element, 'x');
  final y = _doubleAttribute(element, 'y');
  final width = _doubleAttribute(element, 'width');
  final height = _doubleAttribute(element, 'height');
  return Rect.fromLTRB(
    math.min(x, x + width),
    math.min(y, y + height),
    math.max(x, x + width),
    math.max(y, y + height),
  );
}

List<Offset> _elementPoints(Map<String, dynamic> element) {
  final x = _doubleAttribute(element, 'x');
  final y = _doubleAttribute(element, 'y');
  final rawPoints = element['points'];
  if (rawPoints is! List || rawPoints.isEmpty) {
    final width = _doubleAttribute(element, 'width');
    final height = _doubleAttribute(element, 'height');
    return <Offset>[Offset(x, y), Offset(x + width, y + height)];
  }
  return <Offset>[
    for (final point in rawPoints)
      if (point is List && point.length >= 2)
        Offset(x + _doubleValue(point[0]), y + _doubleValue(point[1])),
  ];
}

List<Map<String, dynamic>> _excalidrawVisibleElements(
  Map<String, dynamic> scene,
) {
  final elements = scene['elements'];
  if (elements is! List) {
    return const <Map<String, dynamic>>[];
  }
  return <Map<String, dynamic>>[
    for (final element in elements)
      if (element is Map && element['isDeleted'] != true)
        Map<String, dynamic>.from(element),
  ];
}

Color _excalidrawBackgroundColor(Map<String, dynamic> scene) {
  final appState = scene['appState'];
  if (appState is Map) {
    return _elementColor(
      appState['viewBackgroundColor'],
      const Color(0xfffbfbfb),
    );
  }
  return const Color(0xfffbfbfb);
}

const _excalidrawStrokeColor = Color(0xff1e1e1e);

Color _elementColor(Object? value, Color fallback) {
  if (value is! String) {
    return fallback;
  }
  final normalized = value.trim();
  if (!normalized.startsWith('#')) {
    return fallback;
  }
  final hex = normalized.substring(1);
  if (hex.length == 3) {
    final expanded = hex.split('').map((char) => '$char$char').join();
    return Color(int.parse('ff$expanded', radix: 16));
  }
  if (hex.length == 6) {
    return Color(int.parse('ff$hex', radix: 16));
  }
  if (hex.length == 8) {
    return Color(int.parse(hex, radix: 16));
  }
  return fallback;
}

double _doubleAttribute(
  Map<String, dynamic> element,
  String key, {
  double fallback = 0,
}) {
  return _doubleValue(element[key], fallback: fallback);
}

double _doubleValue(Object? value, {double fallback = 0}) {
  return switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text) ?? fallback,
    _ => fallback,
  };
}

Map<String, dynamic> _emptyExcalidrawScene() {
  return <String, dynamic>{
    'type': 'excalidraw',
    'version': 2,
    'source': 'nx_docs',
    'elements': <dynamic>[],
    'appState': <String, dynamic>{'viewBackgroundColor': '#ffffff'},
    'files': <String, dynamic>{},
  };
}

String _prettyJson(Map<String, dynamic> scene) {
  return const JsonEncoder.withIndent('  ').convert(scene);
}

const _defaultExcalidrawPreviewHeight = 190.0;
const _minExcalidrawPreviewHeight = 120.0;
const _maxExcalidrawPreviewHeight = 620.0;

double _excalidrawPreviewHeightFromNode(Node node) {
  return _clampExcalidrawPreviewHeight(
    _doubleValue(
      node.attributes['preview_height'],
      fallback: _defaultExcalidrawPreviewHeight,
    ),
  );
}

double _clampExcalidrawPreviewHeight(double height) {
  return height.clamp(_minExcalidrawPreviewHeight, _maxExcalidrawPreviewHeight);
}

Map<String, dynamic> _excalidrawSceneFromNode(Node node) {
  final scene = node.attributes['scene'];
  if (scene is Map) {
    return <String, dynamic>{
      ..._emptyExcalidrawScene(),
      ...Map<String, dynamic>.from(scene),
    };
  }
  return _emptyExcalidrawScene();
}

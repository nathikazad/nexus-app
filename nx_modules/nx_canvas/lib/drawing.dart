import 'dart:math' as math;

class Dot {
  const Dot(this.x, this.y, [this.pressure = 1]);
  final double x, y, pressure;
  Dot operator +(Dot other) => Dot(x + other.x, y + other.y, pressure);
  Dot operator -(Dot other) => Dot(x - other.x, y - other.y, pressure);
  Dot operator *(double scale) => Dot(x * scale, y * scale, pressure);
  double get length => math.sqrt(x * x + y * y);
  Dot lerp(Dot b, double t) => Dot(
    x + (b.x - x) * t,
    y + (b.y - y) * t,
    pressure + (b.pressure - pressure) * t,
  );
  List<double> toJson() => [x, y, pressure];
  factory Dot.fromJson(dynamic json) => Dot(
    (json[0] as num).toDouble(),
    (json[1] as num).toDouble(),
    (json[2] as num).toDouble(),
  );
}

class InkStroke {
  InkStroke({
    required this.id,
    required List<Dot> points,
    required this.color,
    required this.width,
  }) : points = List.unmodifiable(points);
  final String id;
  final List<Dot> points;
  final int color;
  final double width;
  InkStroke withPoints(List<Dot> points, {String? id}) =>
      InkStroke(id: id ?? this.id, points: points, color: color, width: width);
  Map<String, dynamic> toJson() => {
    'id': id,
    'points': points.map((p) => p.toJson()).toList(),
    'color': color,
    'width': width,
  };
  factory InkStroke.fromJson(Map<String, dynamic> json) => InkStroke(
    id: json['id'] as String,
    points: (json['points'] as List).map(Dot.fromJson).toList(),
    color: json['color'] as int,
    width: (json['width'] as num).toDouble(),
  );
}

class CanvasView {
  const CanvasView({this.x = 0, this.y = 0, this.scale = 1});
  final double x, y, scale;
  Dot toWorld(Dot screen) =>
      Dot((screen.x - x) / scale, (screen.y - y) / scale);
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'scale': scale};
  factory CanvasView.fromJson(Map<String, dynamic> json) => CanvasView(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    scale: (json['scale'] as num).toDouble().clamp(.05, 8),
  );
}

class SavedPlace {
  const SavedPlace(this.name, this.view);
  final String name;
  final CanvasView view;
  Map<String, dynamic> toJson() => {'name': name, 'view': view.toJson()};
  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
    json['name'] as String,
    CanvasView.fromJson(Map<String, dynamic>.from(json['view'] as Map)),
  );
}

class Drawing {
  Drawing({
    List<InkStroke> strokes = const [],
    this.view = const CanvasView(),
    this.boards,
    List<SavedPlace> places = const [],
  }) : strokes = List.unmodifiable(strokes),
       places = List.unmodifiable(places);
  final List<InkStroke> strokes;
  final Map<String, dynamic>? boards;
  final CanvasView view;
  final List<SavedPlace> places;
  Map<String, dynamic> toJson() => {
    'format': 'nx-canvas',
    'version': 1,
    'strokes': strokes.map((s) => s.toJson()).toList(),
    'view': view.toJson(),
    'places': places.map((p) => p.toJson()).toList(),
    if (boards != null) 'boards': boards,
  };
  factory Drawing.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'nx-canvas' || json['version'] != 1) {
      throw const FormatException('This drawing format is not supported.');
    }
    return Drawing(
      boards: json['boards'] == null
          ? null
          : Map<String, dynamic>.from(json['boards'] as Map),
      strokes: (json['strokes'] as List)
          .map((s) => InkStroke.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      view: CanvasView.fromJson(Map<String, dynamic>.from(json['view'] as Map)),
      places: (json['places'] as List)
          .map((p) => SavedPlace.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }
}

/// Cut a polyline at the exact intersections with an eraser disk. The surviving
/// fragments remain ordinary editable strokes; erasing never paints white ink.
List<InkStroke> eraseDisk(InkStroke stroke, Dot center, double radius) {
  final r = radius + stroke.width / 2;
  if (stroke.points.length == 1) {
    return (stroke.points.first - center).length <= r ? [] : [stroke];
  }
  final fragments = <List<Dot>>[];
  var current = <Dot>[];
  var changed = false;
  for (var i = 1; i < stroke.points.length; i++) {
    final a = stroke.points[i - 1], b = stroke.points[i];
    final d = b - a, f = a - center;
    final aa = d.x * d.x + d.y * d.y;
    final bb = 2 * (f.x * d.x + f.y * d.y);
    final cc = f.x * f.x + f.y * f.y - r * r;
    final disc = bb * bb - 4 * aa * cc;
    final cuts = <double>[0, 1];
    if (aa > 1e-12 && disc > 0) {
      for (final t in [
        (-bb - math.sqrt(disc)) / (2 * aa),
        (-bb + math.sqrt(disc)) / (2 * aa),
      ]) {
        if (t > 0 && t < 1) cuts.add(t);
      }
    }
    cuts.sort();
    for (var j = 1; j < cuts.length; j++) {
      final start = a.lerp(b, cuts[j - 1]), end = a.lerp(b, cuts[j]);
      if ((a.lerp(b, (cuts[j - 1] + cuts[j]) / 2) - center).length < r) {
        changed = true;
        if (current.isNotEmpty) fragments.add(current);
        current = [];
      } else {
        if (current.isEmpty) current.add(start);
        current.add(end);
      }
    }
  }
  if (!changed) return [stroke];
  if (current.isNotEmpty) fragments.add(current);
  return [
    for (var i = 0; i < fragments.length; i++)
      stroke.withPoints(fragments[i], id: '${stroke.id}/$i'),
  ];
}

bool insidePolygon(Dot point, List<Dot> polygon) {
  var inside = false;
  for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i], b = polygon[j];
    if ((a.y > point.y) != (b.y > point.y) &&
        point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// Remove portions of a stroke inside a closed freehand region. Split at edge
/// intersections, including sparse segments whose endpoints are both outside.
/// The remaining pieces retain their pressure samples and editable stroke data.
List<InkStroke> eraseRegion(InkStroke stroke, List<Dot> region) {
  if (region.length < 3) return [stroke];
  double cross(Dot a, Dot b) => a.x * b.y - a.y * b.x;
  final origin = region.first;
  final direction = region
      .skip(1)
      .map((p) => p - origin)
      .firstWhere((d) => d.length > 1e-8, orElse: () => const Dot(0, 0));
  if (!region.any((p) => cross(direction, p - origin).abs() > 1e-8)) {
    return [stroke];
  }

  bool contains(Dot p) {
    for (var i = 0; i < region.length; i++) {
      final a = region[i], b = region[(i + 1) % region.length];
      final d = b - a, v = p - a;
      final length2 = d.x * d.x + d.y * d.y;
      if (length2 < 1e-12) continue;
      final t = (v.x * d.x + v.y * d.y) / length2;
      if (t >= 0 && t <= 1 && (p - a.lerp(b, t)).length < 1e-8) {
        return true;
      }
    }
    return insidePolygon(p, region);
  }

  if (stroke.points.length == 1) {
    return contains(stroke.points.single) ? [] : [stroke];
  }
  final fragments = <List<Dot>>[];
  var current = <Dot>[];
  var changed = false;
  for (var i = 1; i < stroke.points.length; i++) {
    final a = stroke.points[i - 1], b = stroke.points[i], d = b - a;
    final cuts = <double>[0, 1];
    for (var j = 0; j < region.length; j++) {
      final edgeStart = region[j],
          edge = region[(j + 1) % region.length] - edgeStart;
      final offset = edgeStart - a, denominator = cross(d, edge);
      if (denominator.abs() > 1e-10) {
        final t = cross(offset, edge) / denominator;
        final u = cross(offset, d) / denominator;
        if (t > 0 && t < 1 && u >= -1e-10 && u <= 1 + 1e-10) cuts.add(t);
      } else if (cross(offset, d).abs() < 1e-10) {
        final length2 = d.x * d.x + d.y * d.y;
        if (length2 > 1e-12) {
          for (final p in [edgeStart, edgeStart + edge]) {
            final v = p - a;
            final t = (v.x * d.x + v.y * d.y) / length2;
            if (t > 0 && t < 1) cuts.add(t);
          }
        }
      }
    }
    cuts.sort();
    for (var j = 1; j < cuts.length; j++) {
      if (cuts[j] - cuts[j - 1] < 1e-10) continue;
      final start = a.lerp(b, cuts[j - 1]), end = a.lerp(b, cuts[j]);
      if (contains(a.lerp(b, (cuts[j - 1] + cuts[j]) / 2))) {
        changed = true;
        if (current.isNotEmpty) fragments.add(current);
        current = [];
      } else {
        if (current.isEmpty) current.add(start);
        current.add(end);
      }
    }
  }
  if (!changed) return [stroke];
  if (current.isNotEmpty) fragments.add(current);
  return [
    for (var i = 0; i < fragments.length; i++)
      stroke.withPoints(fragments[i], id: '${stroke.id}/region/$i'),
  ];
}

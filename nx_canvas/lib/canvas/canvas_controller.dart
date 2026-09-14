import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'drawing.dart';

enum CanvasTool { pen, eraser, regionEraser, select, hand }

class CanvasController extends ChangeNotifier {
  CanvasController(Drawing drawing)
    : strokes = drawing.strokes,
      view = drawing.view,
      places = drawing.places;
  final inkRepaint = ChangeNotifier();
  final sceneRepaint = ChangeNotifier();
  bool get isDrawing => _before != null;
  bool isDisposed = false;
  final _nativeDeliveries = <String>{};

  @override
  void notifyListeners() {
    sceneRepaint.notifyListeners();
    inkRepaint.notifyListeners();
    super.notifyListeners();
  }

  @override
  void dispose() {
    isDisposed = true;
    inkRepaint.dispose();
    sceneRepaint.dispose();
    super.dispose();
  }

  List<InkStroke> strokes;
  CanvasView view;
  List<SavedPlace> places;
  CanvasTool tool = CanvasTool.pen;
  int color = 0xff283d44;
  double width = 3;
  final selected = <String>{};
  final _undo = <List<InkStroke>>[], _redo = <List<InkStroke>>[];
  final _views = <CanvasView>[];
  List<InkStroke>? _before;
  List<Dot> livePoints = [], lasso = [];
  Dot? _last;
  bool _moving = false;
  int revision = 0, _serial = 0;
  VoidCallback? onCommit;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get canGoBack => _views.isNotEmpty;
  Drawing get drawing => Drawing(strokes: strokes, view: view, places: places);
  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${_serial++}';
  void refresh() => notifyListeners();
  void setTool(CanvasTool value) {
    if (isDrawing) cancel();
    tool = value;
    selected.clear();
    notifyListeners();
  }

  void _commit() {
    revision++;
    onCommit?.call();
    notifyListeners();
  }

  void begin(Dot p) {
    _before = strokes;
    _last = p;
    if (tool == CanvasTool.pen) {
      livePoints = [p];
    }
    if (tool == CanvasTool.eraser) _erase(p, p);
    if (tool == CanvasTool.regionEraser) lasso = [p];
    if (tool == CanvasTool.select) {
      final points = strokes
          .where((s) => selected.contains(s.id))
          .expand((s) => s.points)
          .toList();
      _moving =
          points.isNotEmpty &&
          p.x >= points.map((p) => p.x).reduce(math.min) - 12 / view.scale &&
          p.x <= points.map((p) => p.x).reduce(math.max) + 12 / view.scale &&
          p.y >= points.map((p) => p.y).reduce(math.min) - 12 / view.scale &&
          p.y <= points.map((p) => p.y).reduce(math.max) + 12 / view.scale;
      if (!_moving) {
        selected.clear();
        lasso = [p];
      }
    }
    notifyListeners();
  }

  void update(Dot p) {
    if (_last == null) return;
    if (tool == CanvasTool.pen) livePoints.add(p);
    if (tool == CanvasTool.eraser) _erase(_last!, p);
    if (tool == CanvasTool.regionEraser) lasso.add(p);
    if (tool == CanvasTool.select) {
      if (_moving) {
        final delta = p - _last!;
        strokes = [
          for (final s in strokes)
            selected.contains(s.id)
                ? s.withPoints(s.points.map((p) => p + delta).toList())
                : s,
        ];
      } else {
        lasso.add(p);
      }
    }
    _last = p;
    // Pointer samples repaint ink directly, without rebuilding the app shell.
    if (tool == CanvasTool.eraser || (tool == CanvasTool.select && _moving)) {
      sceneRepaint.notifyListeners();
    }
    inkRepaint.notifyListeners();
  }

  void _erase(Dot a, Dot b) {
    final radius = 12 / view.scale;
    final steps = math.max(1, ((b - a).length / (radius / 2)).ceil());
    for (var i = 0; i <= steps; i++) {
      final center = a.lerp(b, i / steps);
      strokes = strokes.expand((s) => eraseDisk(s, center, radius)).toList();
    }
  }

  void end() {
    if (_before == null) return;
    if (livePoints.isNotEmpty) {
      strokes = [
        ...strokes,
        InkStroke(id: _id(), points: livePoints, color: color, width: width),
      ];
    }
    if (lasso.length >= 3 && tool == CanvasTool.regionEraser) {
      strokes = strokes.expand((s) => eraseRegion(s, lasso)).toList();
    }
    if (lasso.length >= 3 && tool == CanvasTool.select) {
      selected.addAll(
        strokes
            .where((s) => s.points.any((p) => insidePolygon(p, lasso)))
            .map((s) => s.id),
      );
    }
    if (!listEquals(strokes, _before)) {
      _undo.add(_before!);
      if (_undo.length > 100) _undo.removeAt(0);
      _redo.clear();
      _commit();
    }
    _before = null;
    _last = null;
    livePoints = [];
    lasso = [];
    notifyListeners();
  }

  void cancel() {
    if (_before != null) strokes = _before!;
    _before = null;
    _last = null;
    livePoints = [];
    lasso = [];
    notifyListeners();
  }

  void addNativeStroke(
    List<Dot> points, {
    required int color,
    required double width,
    String? sourceId,
  }) {
    if (isDisposed || points.isEmpty) return;
    if (sourceId != null &&
        (!_nativeDeliveries.add(sourceId) ||
            strokes.any((s) => s.id == 'native/$sourceId'))) {
      return;
    }
    _undo.add(strokes);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
    strokes = [
      ...strokes,
      InkStroke(
        id: sourceId == null ? _id() : 'native/$sourceId',
        points: points,
        color: color,
        width: width,
      ),
    ];
    selected.clear();
    _commit();
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(strokes);
    strokes = _undo.removeLast();
    selected.clear();
    _commit();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(strokes);
    strokes = _redo.removeLast();
    selected.clear();
    _commit();
  }

  void rememberView() {
    _views.add(view);
    if (_views.length > 50) _views.removeAt(0);
  }

  void setView(CanvasView next, {bool save = false}) {
    view = next;
    if (save) {
      _commit();
    } else {
      notifyListeners();
    }
  }

  void finishNavigation() => _commit();
  void back() {
    if (canGoBack) {
      view = _views.removeLast();
      _commit();
    }
  }

  void zoom(double factor, Dot anchor) {
    rememberView();
    final world = view.toWorld(anchor),
        scale = (view.scale * factor).clamp(.05, 8.0);
    setView(
      CanvasView(
        x: anchor.x - world.x * scale,
        y: anchor.y - world.y * scale,
        scale: scale,
      ),
      save: true,
    );
  }

  void overview(double width, double height) {
    rememberView();
    if (strokes.isEmpty) {
      setView(const CanvasView(), save: true);
      return;
    }
    final pts = strokes.expand((s) => s.points);
    final minX = pts.map((p) => p.x).reduce(math.min),
        maxX = pts.map((p) => p.x).reduce(math.max);
    final minY = pts.map((p) => p.y).reduce(math.min),
        maxY = pts.map((p) => p.y).reduce(math.max);
    final scale = math
        .min(
          (width - 120) / math.max(1, maxX - minX),
          (height - 120) / math.max(1, maxY - minY),
        )
        .clamp(.05, 2.0);
    setView(
      CanvasView(
        x: width / 2 - (minX + maxX) / 2 * scale,
        y: height / 2 - (minY + maxY) / 2 * scale,
        scale: scale,
      ),
      save: true,
    );
  }

  void addPlace(String name) {
    places = [...places, SavedPlace(name, view)];
    _commit();
  }

  void visit(SavedPlace place) {
    rememberView();
    setView(place.view, save: true);
  }

  void removePlace(SavedPlace place) {
    places = places.where((p) => p != place).toList();
    _commit();
  }
}

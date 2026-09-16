import 'package:flutter/material.dart';

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

  void undo() {
    if (_strokes.isEmpty) return;
    _strokes.removeLast();
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    notifyListeners();
  }
}

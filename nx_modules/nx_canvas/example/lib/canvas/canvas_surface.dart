import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'canvas_controller.dart';
import 'canvas_painter.dart';
import 'drawing.dart';

/// Reusable canvas surface. Hosts supply the controller and persistence policy.
class CanvasSurface extends StatefulWidget {
  const CanvasSurface({super.key, required this.controller});
  final CanvasController controller;
  @override
  State<CanvasSurface> createState() => _CanvasSurfaceState();
}

class _CanvasSurfaceState extends State<CanvasSurface> {
  final _touches = <int, Offset>{};
  int? _inkPointer, _mousePan;
  CanvasTool? _previousTool;
  CanvasView? _gestureView;
  Offset _anchor = Offset.zero;
  double _distance = 1;
  CanvasController get c => widget.controller;
  Dot _dot(Offset p) => Dot(p.dx, p.dy);
  Dot _world(PointerEvent e) {
    final p = c.view.toWorld(_dot(e.localPosition));
    final pressure =
        e.kind == PointerDeviceKind.stylus && e.pressureMax > e.pressureMin
        ? ((e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin))
              .clamp(.1, 1.0)
        : 1.0;
    return Dot(p.x, p.y, pressure);
  }

  Offset get _center =>
      _touches.values.reduce((a, b) => a + b) / _touches.length.toDouble();
  double get _spread => _touches.length < 2
      ? 1
      : (_touches.values.first - _touches.values.last).distance;
  void _resetTouch() {
    if (_touches.isEmpty) return;
    _gestureView = c.view;
    _anchor = _center;
    _distance = math.max(1, _spread);
  }

  void _down(PointerDownEvent e) {
    if (e.kind == PointerDeviceKind.touch) {
      if (_inkPointer != null) return; // Ignore palm contacts during ink.
      if (_touches.isEmpty) c.rememberView();
      _touches[e.pointer] = e.localPosition;
      _resetTouch();
      return;
    }
    if (_inkPointer != null || _mousePan != null) return;
    if (c.tool == CanvasTool.hand ||
        e.buttons == kMiddleMouseButton ||
        e.buttons == kSecondaryMouseButton) {
      _mousePan = e.pointer;
      c.rememberView();
      return;
    }
    _touches.clear();
    _inkPointer = e.pointer;
    if (e.kind == PointerDeviceKind.invertedStylus) {
      _previousTool = c.tool;
      c.tool = CanvasTool.eraser;
    }
    c.begin(_world(e));
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer == _inkPointer) {
      c.update(_world(e));
      return;
    }
    if (e.pointer == _mousePan) {
      c.setView(
        CanvasView(
          x: c.view.x + e.localDelta.dx,
          y: c.view.y + e.localDelta.dy,
          scale: c.view.scale,
        ),
      );
      return;
    }
    if (!_touches.containsKey(e.pointer)) return;
    _touches[e.pointer] = e.localPosition;
    final base = _gestureView!, center = _center;
    final scale = (base.scale * _spread / _distance).clamp(.05, 8.0);
    final world = base.toWorld(_dot(_anchor));
    c.setView(
      CanvasView(
        x: center.dx - world.x * scale,
        y: center.dy - world.y * scale,
        scale: scale,
      ),
    );
  }

  void _up(PointerEvent e, {bool cancel = false}) {
    if (_inkPointer == e.pointer) {
      if (cancel) {
        c.cancel();
      } else {
        c.end();
      }
      _inkPointer = null;
      if (_previousTool != null) {
        c.tool = _previousTool!;
        _previousTool = null;
      }
    }
    if (_mousePan == e.pointer) {
      _mousePan = null;
      c.finishNavigation();
    }
    if (_touches.remove(e.pointer) != null) {
      if (_touches.isEmpty) {
        c.finishNavigation();
      } else {
        _resetTouch();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    key: const ValueKey('canvas-surface'),
    behavior: HitTestBehavior.opaque,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: (e) => _up(e, cancel: true),
    onPointerSignal: (e) {
      if (e is PointerScrollEvent && _inkPointer == null) {
        GestureBinding.instance.pointerSignalResolver.register(e, (_) {
          c.zoom(math.exp(-e.scrollDelta.dy * .002), _dot(e.localPosition));
        });
      }
    },
    onPointerPanZoomStart: (e) {
      if (_inkPointer != null) return;
      c.rememberView();
      _gestureView = c.view;
      _anchor = e.localPosition;
    },
    onPointerPanZoomUpdate: (e) {
      if (_inkPointer != null || _gestureView == null) return;
      final base = _gestureView!,
          scale = (_gestureView!.scale * e.scale).clamp(.05, 8.0);
      final world = base.toWorld(_dot(_anchor));
      c.setView(
        CanvasView(
          x: _anchor.dx + e.pan.dx - world.x * scale,
          y: _anchor.dy + e.pan.dy - world.y * scale,
          scale: scale,
        ),
      );
    },
    onPointerPanZoomEnd: (_) {
      if (_inkPointer == null) c.finishNavigation();
    },
    child: MouseRegion(
      cursor: c.tool == CanvasTool.hand
          ? SystemMouseCursors.grab
          : SystemMouseCursors.precise,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: const ValueKey('canvas-scene-layer'),
            child: CustomPaint(painter: CanvasPainter(c)),
          ),
          RepaintBoundary(
            key: const ValueKey('canvas-ink-layer'),
            child: CustomPaint(painter: CanvasPainter(c, overlay: true)),
          ),
        ],
      ),
    ),
  );
}

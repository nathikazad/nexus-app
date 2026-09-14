import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'canvas_controller.dart';
import 'drawing.dart';

/// Android-only native preview. Strokes cross back as ordinary world-space ink.
class NativeInkSurface extends StatefulWidget {
  const NativeInkSurface({
    super.key,
    required this.controller,
    required this.onUnavailable,
    this.topInset = 82,
  });
  final CanvasController controller;
  final ValueChanged<String> onUnavailable;
  final double topInset;
  @override
  State<NativeInkSurface> createState() => _NativeInkSurfaceState();
}

class _NativeInkSurfaceState extends State<NativeInkSurface> {
  MethodChannel? _channel;
  double _density = 1;
  bool _accepting = false;
  List<InkStroke>? _lastStrokes;
  CanvasView? _lastView;
  int? _lastColor;
  double? _lastWidth;
  late final CanvasController _controller = widget.controller;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sendScene);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextDensity = MediaQuery.devicePixelRatioOf(context);
    if (nextDensity != _density) _lastStrokes = null;
    _density = nextDensity;
    _sendScene();
  }

  void _sendScene() {
    final channel = _channel;
    if (channel == null || _accepting) return;
    final c = _controller;
    final sceneChanged =
        !identical(_lastStrokes, c.strokes) || !identical(_lastView, c.view);
    final styleChanged = _lastColor != c.color || _lastWidth != c.width;
    if (!sceneChanged && !styleChanged) return;
    _lastStrokes = c.strokes;
    _lastView = c.view;
    _lastColor = c.color;
    _lastWidth = c.width;
    channel
        .invokeMethod<void>(sceneChanged ? 'scene' : 'style', {
          if (sceneChanged) ...c.drawing.toJson(),
          'density': _density,
          'topInset': widget.topInset,
          'color': c.color,
          'width': c.width,
        })
        .catchError((Object error) {
          if (mounted) widget.onUnavailable(error.toString());
        });
  }

  void _accept(dynamic value) {
    if (_controller.isDisposed) return;
    final data = Map<String, dynamic>.from(value as Map);
    _accepting = true;
    try {
      _controller.addNativeStroke(
        (data['points'] as List).map(Dot.fromJson).toList(),
        color: data['color'] as int,
        width: (data['width'] as num).toDouble(),
        sourceId: data['id'] as String?,
      );
      // The widget already displays this stroke. A full scene echo would reset
      // its ink buffers and interrupt the next handwritten stroke.
      _lastStrokes = _controller.strokes;
    } finally {
      _accepting = false;
    }
  }

  Future<dynamic> _receive(MethodCall call) async {
    if (call.method == 'unavailable' && mounted) {
      widget.onUnavailable(call.arguments.toString());
    }
    if (call.method == 'stroke') _accept(call.arguments);
  }

  Future<void> _stop(MethodChannel channel) async {
    try {
      final pending = await channel.invokeListMethod<dynamic>('stop');
      for (final stroke in pending ?? []) {
        _accept(stroke);
      }
    } finally {
      // Leave the handler alive through the native teardown's final pen-up.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      channel.setMethodCallHandler(null);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_sendScene);
    final channel = _channel;
    if (channel != null) _stop(channel).catchError((Object _) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlatformViewLink(
    viewType: 'nx_canvas/native',
    surfaceFactory: (context, controller) => AndroidViewSurface(
      controller: controller as AndroidViewController,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      hitTestBehavior: PlatformViewHitTestBehavior.opaque,
    ),
    onCreatePlatformView: (params) {
      final view = PlatformViewsService.initExpensiveAndroidView(
        id: params.id,
        viewType: 'nx_canvas/native',
        layoutDirection: TextDirection.ltr,
        creationParams: const {},
        creationParamsCodec: const StandardMessageCodec(),
      );
      view.addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
      view.addOnPlatformViewCreatedListener((id) {
        _channel = MethodChannel('nx_canvas/native/$id')
          ..setMethodCallHandler(_receive);
        _sendScene();
      });
      view.create();
      return view;
    },
  );
}

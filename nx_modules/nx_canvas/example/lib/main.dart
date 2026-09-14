import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'canvas/canvas_controller.dart';
import 'canvas/canvas_painter.dart';
import 'canvas/canvas_surface.dart';
import 'canvas/native_ink_surface.dart';
import 'canvas/drawing.dart';
import 'storage/canvas_store.dart';
import 'gallery.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CanvasApp());
}

class CanvasApp extends StatelessWidget {
  const CanvasApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NX Canvas',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff236b5e),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xfff8f8f3),
    ),
    home: const CanvasGallery(),
  );
}

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key, this.store});
  final CanvasStore? store;
  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> with WidgetsBindingObserver {
  CanvasStore? _store;
  CanvasController? _controller;
  Timer? _debounce;
  Future<void>? _saving;
  int _savedRevision = 0;
  String? _loadError, _saveError;
  Size _surfaceSize = Size.zero;
  bool _help = false;
  bool _nativeAvailable = true;
  bool _nativeReady = false;
  bool _placesOpen = false;
  bool _penMenuOpen = false;
  bool get _nativeVisible =>
      _hasNativeEditor &&
      _nativeAvailable &&
      _nativeReady &&
      !_help &&
      !_placesOpen &&
      !_penMenuOpen &&
      _controller?.tool == CanvasTool.pen;
  bool get _hasNativeEditor =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static const _editor = MethodChannel('nx_canvas/editor');
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        _controller?.end();
        await _flush();
        return _saveError == null
            ? AppExitResponse.exit
            : AppExitResponse.cancel;
      },
    );
    _load();
  }

  Future<void> _load() async {
    try {
      _store = widget.store ?? await CanvasStore.open();
      final drawing = await _store!.load();
      if (!mounted) return;
      _controller = CanvasController(drawing)..onCommit = _scheduleSave;
      if (_hasNativeEditor) {
        _controller!.color = 0xff000000;
        await _importNative(await _editor.invokeListMethod<dynamic>('recover'));
      }
      if (!mounted) return;
      setState(() => _nativeReady = true);
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  Future<void> _importNative(List<dynamic>? records) async {
    final c = _controller!;
    for (final item in records ?? []) {
      final data = Map<String, dynamic>.from(item as Map);
      c.addNativeStroke(
        (data['points'] as List).map(Dot.fromJson).toList(),
        color: data['color'] as int,
        width: (data['width'] as num).toDouble(),
        sourceId: data['id'] as String,
      );
    }
    do {
      await _flush();
      if (_saveError != null) throw StateError(_saveError!);
    } while (_savedRevision != c.revision);
    // Delete the handoff journal only after the editable drawing is in SQLite.
    await _editor.invokeMethod<void>('ack');
  }

  void _choosePen() => _controller!.setTool(CanvasTool.pen);

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _flush);
    if (mounted) setState(() {});
  }

  Future<void> _flush() async {
    _debounce?.cancel();
    if (_saving != null) {
      await _saving;
      return;
    }
    _saving = _drain();
    await _saving;
    _saving = null;
  }

  Future<void> _drain() async {
    final c = _controller;
    if (c == null) return;
    while (_savedRevision != c.revision) {
      // Do not rasterize a thumbnail while the next stroke is being drawn.
      if (c.isDrawing) {
        _debounce = Timer(const Duration(milliseconds: 250), _flush);
        return;
      }
      final revision = c.revision, drawing = c.drawing;
      try {
        final preview = await renderPreview(drawing);
        await _store!.save(drawing, preview);
        _savedRevision = revision;
        _saveError = null;
      } catch (e) {
        _saveError = e.toString();
        break;
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _controller?.end();
      unawaited(_flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.dispose();
    _debounce?.cancel();
    _controller?.onCommit = null;
    // The app owns the database for its lifetime. Exit is flushed above.
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _places() async {
    setState(() => _placesOpen = true);
    final c = _controller!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved places',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bookmarks in one continuous canvas. Your drawing stays connected.',
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final place in c.places)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.bookmark_outline),
                          title: Text(place.name),
                          onTap: () {
                            c.visit(place);
                            Navigator.pop(context);
                          },
                          trailing: IconButton(
                            tooltip: 'Remove place',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              c.removePlace(place);
                              update(() {});
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final text = TextEditingController();
                    final name = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Name this view'),
                        content: TextField(
                          controller: text,
                          autofocus: true,
                          maxLength: 60,
                          decoration: const InputDecoration(
                            hintText: 'Opening ideas',
                          ),
                          onSubmitted: (value) => Navigator.pop(context, value),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, text.text),
                            child: const Text('Save place'),
                          ),
                        ],
                      ),
                    );
                    // The dialog may still be animating out; let it finish using its controller.
                    if (name != null && name.trim().isNotEmpty) {
                      c.addPlace(name.trim());
                      update(() {});
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Save current view'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _placesOpen = false);
  }

  Widget _button(
    String label,
    IconData icon,
    VoidCallback? action, {
    bool active = false,
  }) => IconButton.filledTonal(
    tooltip: label,
    onPressed: action,
    isSelected: active,
    style: IconButton.styleFrom(
      backgroundColor: active ? const Color(0xffd2e9df) : Colors.transparent,
    ),
    icon: Icon(icon, size: 21),
  );
  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return Scaffold(
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Your canvas could not be opened. The saved data has been left intact.',
                      ),
                      const SizedBox(height: 12),
                      SelectableText(_loadError!),
                      TextButton(
                        onPressed: () async {
                          await _store?.close();
                          _store = null;
                          setState(() => _loadError = null);
                          await _load();
                        },
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): c.undo,
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            meta: true,
            shift: true,
          ): c.redo,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): c.undo,
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): c.redo,
          const SingleActivator(LogicalKeyboardKey.keyP): _choosePen,
          const SingleActivator(LogicalKeyboardKey.keyE): () =>
              c.setTool(CanvasTool.eraser),
          const SingleActivator(LogicalKeyboardKey.keyR): () =>
              c.setTool(CanvasTool.regionEraser),
          const SingleActivator(LogicalKeyboardKey.keyL): () =>
              c.setTool(CanvasTool.select),
          const SingleActivator(LogicalKeyboardKey.keyH): () =>
              c.setTool(CanvasTool.hand),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gesture, color: Color(0xff236b5e)),
                        const SizedBox(width: 10),
                        const Text(
                          'NX Canvas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (_saveError != null)
                          TextButton.icon(
                            onPressed: _flush,
                            icon: const Icon(Icons.warning_amber),
                            label: const Text('Save failed · Retry'),
                          )
                        else
                          Text(
                            _savedRevision == c.revision
                                ? 'Saved on this device'
                                : 'Saving…',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff526761),
                            ),
                          ),
                        IconButton(
                          tooltip: 'Canvas help',
                          onPressed: () => setState(() => _help = !_help),
                          icon: const Icon(Icons.help_outline, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _surfaceSize = constraints.biggest;
                        return Stack(
                          children: [
                            if (_nativeVisible)
                              Positioned.fill(
                                top: 82,
                                child: NativeInkSurface(
                                  controller: c,
                                  onUnavailable: (reason) {
                                    if (!mounted) return;
                                    setState(() => _nativeAvailable = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Native handwriting unavailable: $reason',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            else
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: CanvasSurface(controller: c),
                                ),
                              ),
                            if (!_nativeVisible &&
                                c.strokes.isEmpty &&
                                c.livePoints.isEmpty)
                              const Positioned.fill(
                                child: IgnorePointer(
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Room to think.',
                                          style: TextStyle(
                                            fontSize: 32,
                                            color: Color(0xff62756c),
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'Draw anywhere. Follow an idea in any direction.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xff748078),
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Pen or mouse to draw · Fingers or trackpad to move',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xff748078),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 14,
                              left: 14,
                              right: 14,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Material(
                                  elevation: 2,
                                  shadowColor: const Color(0x22000000),
                                  color: const Color(0xfffefefa),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _button(
                                          'Pen (P)',
                                          Icons.edit_outlined,
                                          _choosePen,
                                          active: c.tool == CanvasTool.pen,
                                        ),
                                        _button(
                                          'Rub eraser (E)',
                                          Icons.auto_fix_normal,
                                          () => c.setTool(CanvasTool.eraser),
                                          active: c.tool == CanvasTool.eraser,
                                        ),
                                        _button(
                                          'Region eraser: draw a loop (R)',
                                          Icons.highlight_remove_outlined,
                                          () => c.setTool(
                                            CanvasTool.regionEraser,
                                          ),
                                          active:
                                              c.tool == CanvasTool.regionEraser,
                                        ),
                                        _button(
                                          'Lasso and move (L)',
                                          Icons.gesture,
                                          () => c.setTool(CanvasTool.select),
                                          active: c.tool == CanvasTool.select,
                                        ),
                                        _button(
                                          'Move canvas (H)',
                                          Icons.pan_tool_outlined,
                                          () => c.setTool(CanvasTool.hand),
                                          active: c.tool == CanvasTool.hand,
                                        ),
                                        const SizedBox(width: 8),
                                        for (final entry in <String, int>{
                                          if (_hasNativeEditor)
                                            'Black': 0xff000000,
                                          if (!_hasNativeEditor) ...{
                                            'Graphite': 0xff283d44,
                                            'Teal': 0xff168274,
                                            'Orange': 0xffcc693d,
                                            'Purple': 0xff8064b0,
                                          },
                                        }.entries)
                                          IconButton(
                                            tooltip: entry.key,
                                            onPressed: () {
                                              c.color = entry.value;
                                              c.setTool(CanvasTool.pen);
                                            },
                                            icon: Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: Color(entry.value),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: c.color == entry.value
                                                      ? Colors.white
                                                      : Colors.transparent,
                                                  width: 3,
                                                ),
                                                boxShadow:
                                                    c.color == entry.value
                                                    ? [
                                                        BoxShadow(
                                                          color: Color(
                                                            entry.value,
                                                          ),
                                                          spreadRadius: 1.5,
                                                        ),
                                                      ]
                                                    : [],
                                              ),
                                            ),
                                          ),
                                        PopupMenuButton<double>(
                                          tooltip: 'Pen thickness',
                                          onOpened: () => setState(
                                            () => _penMenuOpen = true,
                                          ),
                                          onCanceled: () => setState(
                                            () => _penMenuOpen = false,
                                          ),
                                          initialValue: c.width,
                                          onSelected: (value) {
                                            c.width = value;
                                            setState(
                                              () => _penMenuOpen = false,
                                            );
                                            c.refresh();
                                          },
                                          itemBuilder: (_) => [
                                            for (final value in [
                                              1.5,
                                              3.0,
                                              6.0,
                                              10.0,
                                            ])
                                              PopupMenuItem(
                                                value: value,
                                                child: Text(
                                                  '${value.toStringAsFixed(1)} pt',
                                                ),
                                              ),
                                          ],
                                          icon: const Icon(
                                            Icons.line_weight,
                                            size: 20,
                                          ),
                                        ),
                                        _button(
                                          'Undo drawing',
                                          Icons.undo,
                                          c.canUndo ? c.undo : null,
                                        ),
                                        _button(
                                          'Redo drawing',
                                          Icons.redo,
                                          c.canRedo ? c.redo : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (c.tool == CanvasTool.regionEraser ||
                                c.tool == CanvasTool.eraser)
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 16,
                                child: IgnorePointer(
                                  child: Center(
                                    child: Material(
                                      color: const Color(0xfffefefa),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          c.tool == CanvasTool.regionEraser
                                              ? 'Region eraser · Draw a loop, then lift to erase inside'
                                              : 'Rub eraser · Rub over the ink to erase it',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_help)
                              Positioned(
                                top: 100,
                                right: 16,
                                left: 16,
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 340,
                                    ),
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Find your flow',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'Draw with a stylus or mouse.\nPan with a finger, trackpad, or Hand tool.\nPinch to zoom; a mouse wheel also zooms.\nLasso ink, then drag inside its selection.\nRub eraser removes the parts you touch.\nRegion eraser: draw a loop, then lift to erase inside.\nUndo restores either kind of erasing.\nOverview fits your drawing on screen.\nBack returns to your previous view.\nSaved places bookmark any area.',
                                            ),
                                            const SizedBox(height: 12),
                                            TextButton(
                                              onPressed: () =>
                                                  setState(() => _help = false),
                                              child: const Text('Got it'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _button(
                              'Back to previous view',
                              Icons.arrow_back,
                              c.canGoBack ? c.back : null,
                            ),
                            TextButton.icon(
                              onPressed: () => c.overview(
                                _surfaceSize.width,
                                _surfaceSize.height,
                              ),
                              icon: const Icon(Icons.zoom_out_map, size: 18),
                              label: const Text('Overview'),
                            ),
                            TextButton.icon(
                              onPressed: _places,
                              icon: const Icon(
                                Icons.bookmarks_outlined,
                                size: 18,
                              ),
                              label: const Text('Places'),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _button(
                              'Zoom out',
                              Icons.remove,
                              () => c.zoom(
                                .8,
                                Dot(
                                  _surfaceSize.width / 2,
                                  _surfaceSize.height / 2,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: Text(
                                '${(c.view.scale * 100).round()}%',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            _button(
                              'Zoom in',
                              Icons.add,
                              () => c.zoom(
                                1.25,
                                Dot(
                                  _surfaceSize.width / 2,
                                  _surfaceSize.height / 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

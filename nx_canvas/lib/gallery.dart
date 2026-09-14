import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'canvas/canvas_painter.dart';
import 'canvas/drawing.dart';
import 'storage/canvas_store.dart';
import 'storage/native_canvas_handoff.dart';
import 'main.dart' show CanvasPage;

class CanvasGallery extends StatefulWidget {
  const CanvasGallery({super.key, this.store});
  final CanvasStore? store;
  @override
  State<CanvasGallery> createState() => _CanvasGalleryState();
}

class _CanvasGalleryState extends State<CanvasGallery> {
  static const _native = MethodChannel('nx_canvas/editor');
  CanvasStore? _store;
  List<CanvasTileData> _tiles = [];
  bool _loading = true, _busy = false;
  String? _error;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _store ??= widget.store ?? await CanvasStore.open();
      if (_android) await _recover();
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    final tiles = await _store!.listCanvases();
    if (mounted) {
      setState(() {
        _tiles = tiles;
        _loading = false;
        _error = null;
      });
    }
  }

  Future<void> _saveNative(dynamic value) =>
      NativeCanvasHandoff(_store!, channel: _native).save(value);
  Future<void> _recover() =>
      NativeCanvasHandoff(_store!, channel: _native).recover();

  Future<void> _open(CanvasTileData tile) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_android) {
        await _recover();
        final drawing = await _store!.loadCanvas(tile.id);
        final result = await _native.invokeMethod<dynamic>('openDocument', {
          ...drawing.toJson(),
          'documentId': tile.id,
          'title': tile.title,
        });
        await _saveNative(result);
      } else if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(tile.title)),
              body: CanvasPage(store: _store!.forCanvas(tile.id, tile.title)),
            ),
          ),
        );
      }
      await _refresh();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    if (mounted) setState(() => _error = error.toString());
  }

  Future<String?> _name(String initial, String heading) async {
    final input = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(heading),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Drawing name'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().isNotEmpty) {
                Navigator.pop(context, input.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Dialog route retains its text controller during the dismissal animation.
    Future<void>.delayed(const Duration(seconds: 1), input.dispose);
    return result;
  }

  Future<void> _create() async {
    if (_busy || _store == null) return;
    final name = await _name('Drawing ${_tiles.length + 1}', 'New drawing');
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    CanvasTileData? created;
    try {
      final id = 'canvas-${DateTime.now().microsecondsSinceEpoch}';
      final drawing = Drawing();
      final preview = await renderPreview(drawing);
      await _store!.saveCanvas(id, name, drawing, preview);
      await _refresh();
      created = _tiles.firstWhere((tile) => tile.id == id);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (created != null && mounted) await _open(created);
  }

  Future<void> _rename(CanvasTileData tile) async {
    final name = await _name(tile.title, 'Rename drawing');
    if (name == null) return;
    try {
      await _store!.renameCanvas(tile.id, name);
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff5f5ef),
    appBar: AppBar(
      backgroundColor: const Color(0xfff5f5ef),
      title: const Text('NX Canvas'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: FilledButton.icon(
            onPressed: _busy || _loading ? null : _create,
            icon: const Icon(Icons.add),
            label: const Text('New drawing'),
          ),
        ),
      ],
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 6),
          child: Text(
            'Your drawings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Text(
            'Tap a drawing to open your canvas.',
            style: TextStyle(color: Color(0xff59635d)),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: MaterialBanner(
              content: Text('Could not finish: $_error'),
              actions: [
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _tiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.draw_outlined,
                        size: 56,
                        color: Color(0xff708176),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'A place for your next idea.',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _create,
                        child: const Text('Create a drawing'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                  ),
                  itemCount: _tiles.length,
                  itemBuilder: (context, index) {
                    final tile = _tiles[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xffdce1d9)),
                      ),
                      child: InkWell(
                        onTap: _busy ? null : () => _open(tile),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _Preview(bytes: tile.preview)),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tile.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          _date(tile.updatedAt),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xff69746d),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Rename ${tile.title}',
                                    onPressed: _busy
                                        ? null
                                        : () => _rename(tile),
                                    icon: const Icon(Icons.more_horiz),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
  String _date(DateTime value) {
    final d = value.toLocal();
    return '${d.month}/${d.day}/${d.year}';
  }
}

class _Preview extends StatelessWidget {
  const _Preview({this.bytes});
  final Uint8List? bytes;
  @override
  Widget build(BuildContext context) => bytes == null || bytes!.isEmpty
      ? const Center(
          child: Icon(Icons.draw_outlined, size: 40, color: Color(0xff93a098)),
        )
      : Image.memory(
          bytes!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              const Center(child: Icon(Icons.draw_outlined, size: 40)),
        );
}

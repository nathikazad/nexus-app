part of 'nx_appflowy_blocks.dart';

class _ExcalidrawDialog extends StatefulWidget {
  const _ExcalidrawDialog({required this.initialScene, required this.onSave});

  final Map<String, dynamic> initialScene;
  final ValueChanged<Map<String, dynamic>> onSave;

  @override
  State<_ExcalidrawDialog> createState() => _ExcalidrawDialogState();
}

class _ExcalidrawDialogState extends State<_ExcalidrawDialog> {
  late Map<String, dynamic> _scene;
  late final TextEditingController _jsonController;
  var _saved = false;
  var _showJson = false;
  var _jsonDirty = false;
  String? _jsonError;
  var _frameSerial = 0;
  var _saveRequest = 0;

  @override
  void initState() {
    super.initState();
    _scene = Map<String, dynamic>.from(widget.initialScene);
    _jsonController = TextEditingController(text: _prettyJson(_scene));
    _jsonController.addListener(() {
      if (!_jsonDirty) {
        setState(() => _jsonDirty = true);
      }
    });
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.draw_outlined, size: 18, color: AppColors.muted),
                  const SizedBox(width: 8),
                  Text(
                    'Excalidraw',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_saved)
                    Text(
                      'Saved',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _toggleJson,
                    icon: const Icon(Icons.data_object, size: 17),
                    label: const Text('JSON'),
                    style: TextButton.styleFrom(
                      foregroundColor: _showJson
                          ? AppColors.text
                          : AppColors.muted,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _requestFrameSave,
                    icon: const Icon(Icons.save_outlined, size: 17),
                    label: const Text('Save'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Done',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 20, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: NxExcalidrawEditorFrame(
                      key: ValueKey<int>(_frameSerial),
                      scene: _scene,
                      onSave: _saveScene,
                      saveRequest: _saveRequest,
                    ),
                  ),
                  if (_showJson)
                    _JsonSceneEditor(
                      controller: _jsonController,
                      dirty: _jsonDirty,
                      error: _jsonError,
                      onApply: _applyJson,
                      onRevert: _revertJson,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveScene(Map<String, dynamic> scene) {
    _scene = Map<String, dynamic>.from(scene);
    widget.onSave(_scene);
    _jsonController.text = _prettyJson(_scene);
    if (mounted) {
      setState(() {
        _saved = true;
        _jsonDirty = false;
        _jsonError = null;
      });
    }
  }

  void _toggleJson() {
    setState(() {
      _showJson = !_showJson;
      if (_showJson && !_jsonDirty) {
        _jsonController.text = _prettyJson(_scene);
      }
    });
  }

  void _requestFrameSave() {
    setState(() => _saveRequest += 1);
  }

  void _applyJson() {
    try {
      final decoded = jsonDecode(_jsonController.text);
      if (decoded is! Map) {
        throw const FormatException('Scene JSON must be an object.');
      }
      final scene = <String, dynamic>{
        ..._emptyExcalidrawScene(),
        ...Map<String, dynamic>.from(decoded),
      };
      _scene = scene;
      widget.onSave(_scene);
      _jsonController.text = _prettyJson(_scene);
      setState(() {
        _saved = true;
        _jsonDirty = false;
        _jsonError = null;
        _frameSerial += 1;
      });
    } catch (error) {
      setState(() => _jsonError = error.toString());
    }
  }

  void _revertJson() {
    _jsonController.text = _prettyJson(_scene);
    setState(() {
      _jsonDirty = false;
      _jsonError = null;
    });
  }
}

class _JsonSceneEditor extends StatelessWidget {
  const _JsonSceneEditor({
    required this.controller,
    required this.dirty,
    required this.error,
    required this.onApply,
    required this.onRevert,
  });

  final TextEditingController controller;
  final bool dirty;
  final String? error;
  final VoidCallback onApply;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  'Scene JSON',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: dirty ? onRevert : null,
                  child: const Text('Revert'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: dirty ? onApply : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.floating,
                    foregroundColor: AppColors.onFloating,
                    disabledBackgroundColor: AppColors.line,
                    disabledForegroundColor: AppColors.faint,
                    minimumSize: const Size(70, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.text,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.sidebar,
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: AppColors.hover),
                  ),
                ),
              ),
            ),
          ),
          if (error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Text(
                error!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffb91c1c),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

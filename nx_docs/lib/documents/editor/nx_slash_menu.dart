part of 'nx_appflowy_blocks.dart';

CharacterShortcutEvent nxSlashCommand({
  required Future<List<LinkedModel>> Function({
    required LinkableModelType modelType,
    required String query,
  })
  searchLinkableModels,
  required Future<LinkedModel> Function(String title) createLinkedDocument,
  required Future<void> Function(LinkableModelType modelType, LinkedModel model)
  onLinkableModelSelected,
  Future<String> Function(String source)? uploadDocumentImage,
}) {
  return CharacterShortcutEvent(
    key: 'show nx slash menu',
    character: '/',
    handler: (editorState) async {
      final selection = editorState.selection;
      if (selection == null || !selection.isCollapsed) {
        return false;
      }
      final node = editorState.getNodeAtPath(selection.start.path);
      if (node == null || node.delta == null) {
        return false;
      }
      await editorState.insertTextAtPosition('/', position: selection.start);
      final context = node.context;
      if (context == null || !context.mounted) {
        return true;
      }
      _showNxSlashOverlay(
        context,
        editorState,
        searchLinkableModels: searchLinkableModels,
        createLinkedDocument: createLinkedDocument,
        onLinkableModelSelected: onLinkableModelSelected,
        uploadDocumentImage: uploadDocumentImage,
      );
      return true;
    },
  );
}

List<SelectionMenuItem> _nxStaticSelectionMenuItems({
  Future<String> Function(String source)? uploadDocumentImage,
}) {
  return <SelectionMenuItem>[
    SelectionMenuItem.node(
      getName: () => 'Toggle',
      keywords: const <String>['toggle', 'details', 'collapse'],
      iconData: Icons.expand_circle_down_outlined,
      nodeBuilder: (_, __) => nxToggleNode(),
      replace: _replaceCurrentParagraph,
    ),
    SelectionMenuItem.node(
      getName: () => 'Excalidraw',
      keywords: const <String>['excalidraw', 'drawing', 'diagram', 'canvas'],
      iconData: Icons.draw_outlined,
      nodeBuilder: (_, __) => nxExcalidrawNode(),
      replace: _replaceCurrentParagraph,
    ),
    _nxImageSelectionMenuItem(uploadDocumentImage: uploadDocumentImage),
    for (final item in standardSelectionMenuItems)
      if (!item.allKeywords.contains('image')) item,
  ];
}

SelectionMenuItem _nxImageSelectionMenuItem({
  Future<String> Function(String source)? uploadDocumentImage,
}) {
  return SelectionMenuItem(
    getName: () => AppFlowyEditorL10n.current.image,
    icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
      name: 'image',
      isSelected: isSelected,
      style: style,
    ),
    keywords: const <String>['image'],
    handler: (editorState, menuService, context) {
      unawaited(
        _showNxImageUploadDialog(
          context: context,
          editorState: editorState,
          uploadDocumentImage: uploadDocumentImage,
        ),
      );
    },
  );
}

Future<void> _showNxImageUploadDialog({
  required BuildContext context,
  required EditorState editorState,
  required Future<String> Function(String source)? uploadDocumentImage,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _NxImageUploadDialog(
        onInsert: (source) {
          return _insertDocumentImageSource(
            editorState: editorState,
            source: source,
            uploadDocumentImage: uploadDocumentImage,
          );
        },
      );
    },
  );
}

Future<void> _insertDocumentImageSource({
  required EditorState editorState,
  required String source,
  required Future<String> Function(String source)? uploadDocumentImage,
}) async {
  final url = uploadDocumentImage == null
      ? source
      : await uploadDocumentImage(source);
  await editorState.insertImageNode(url);
}

class _NxImageUploadDialog extends StatefulWidget {
  const _NxImageUploadDialog({required this.onInsert});

  final Future<void> Function(String source) onInsert;

  @override
  State<_NxImageUploadDialog> createState() => _NxImageUploadDialogState();
}

class _NxImageUploadDialogState extends State<_NxImageUploadDialog> {
  static const _allowedExtensions = <String>['jpg', 'jpeg', 'png'];

  final _urlController = TextEditingController();
  var _tabIndex = 0;
  var _picking = false;
  var _submitting = false;
  String? _selectedSource;
  String? _selectedFileName;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.panel,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildHeader(context),
                const SizedBox(height: 14),
                _buildTabs(),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  child: _tabIndex == 0 ? _buildUploadTab() : _buildUrlTab(),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: AppColors.red,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.subtle,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.image_outlined, size: 17, color: AppColors.muted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Insert image',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Close',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          icon: Icon(Icons.close, size: 17, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: <Widget>[
          _NxImageUploadTabButton(
            label: 'Upload',
            selected: _tabIndex == 0,
            onPressed: _submitting ? null : () => setState(() => _tabIndex = 0),
          ),
          _NxImageUploadTabButton(
            label: 'URL',
            selected: _tabIndex == 1,
            onPressed: _submitting ? null : () => setState(() => _tabIndex = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTab() {
    final fileName = _selectedFileName;
    return InkWell(
      key: const ValueKey('upload'),
      borderRadius: BorderRadius.circular(6),
      onTap: _submitting || _picking ? null : _pickImage,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: SizedBox(
          height: 142,
          width: double.infinity,
          child: Center(
            child: _picking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        fileName == null
                            ? Icons.upload_file_outlined
                            : Icons.check_circle_outline,
                        size: 30,
                        color: fileName == null
                            ? AppColors.muted
                            : AppColors.green,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        fileName ?? 'Choose JPG or PNG',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Click to select an image',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrlTab() {
    return Column(
      key: const ValueKey('url'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _urlController,
          enabled: !_submitting,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: 'https://example.com/image.png',
            prefixIcon: Icon(Icons.link, size: 17),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.floating,
            foregroundColor: AppColors.onFloating,
            disabledBackgroundColor: AppColors.line,
            disabledForegroundColor: AppColors.faint,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onFloating,
                  ),
                )
              : const Text('Insert'),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: file_picker.FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: kIsWeb,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.single;
      final source = _sourceForPickedFile(file);
      setState(() {
        _selectedSource = source;
        _selectedFileName = file.name;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not choose image: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  String _sourceForPickedFile(file_picker.PlatformFile file) {
    final path = file.path;
    if (!kIsWeb && path != null && path.isNotEmpty) {
      return path;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Could not read selected image bytes');
    }
    return _dataUrlForPickedFile(bytes, file.name);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final source = _tabIndex == 0
        ? _selectedSource
        : _urlController.text.trim();
    if (source == null || source.isEmpty) {
      setState(() {
        _error = _tabIndex == 0
            ? 'Choose an image file first.'
            : 'Enter an image URL first.';
      });
      return;
    }
    if (_tabIndex == 1 && !_isHttpImageUrl(source)) {
      setState(() => _error = 'Enter a valid http or https image URL.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onInsert(source);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Could not insert image: $error';
        });
      }
    }
  }
}

class _NxImageUploadTabButton extends StatelessWidget {
  const _NxImageUploadTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: selected ? AppColors.text : AppColors.muted,
            backgroundColor: selected ? AppColors.panel : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            minimumSize: const Size(0, 32),
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

String _dataUrlForPickedFile(Uint8List bytes, String fileName) {
  return 'data:${_mimeTypeForImageName(fileName)};base64,${base64Encode(bytes)}';
}

String _mimeTypeForImageName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  return 'image/png';
}

bool _isHttpImageUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

void _showNxSlashOverlay(
  BuildContext anchorContext,
  EditorState editorState, {
  required Future<List<LinkedModel>> Function({
    required LinkableModelType modelType,
    required String query,
  })
  searchLinkableModels,
  required Future<LinkedModel> Function(String title) createLinkedDocument,
  required Future<void> Function(LinkableModelType modelType, LinkedModel model)
  onLinkableModelSelected,
  Future<String> Function(String source)? uploadDocumentImage,
}) {
  final overlay = Overlay.of(anchorContext);
  final renderBox = anchorContext.findRenderObject() as RenderBox?;
  final anchor = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
  late final OverlayEntry entry;
  late final _NxSelectionMenuService menuService;
  entry = OverlayEntry(
    builder: (context) {
      menuService = _NxSelectionMenuService(
        entry: entry,
        style: SelectionMenuStyle.light,
      );
      return Positioned(
        left: anchor.dx + 8,
        top: anchor.dy + 28,
        child: NxSlashMenuOverlay(
          editorState: editorState,
          menuService: menuService,
          searchLinkableModels: searchLinkableModels,
          createLinkedDocument: createLinkedDocument,
          onLinkableModelSelected: onLinkableModelSelected,
          uploadDocumentImage: uploadDocumentImage,
          onDismiss: () {
            if (entry.mounted) {
              entry.remove();
            }
          },
        ),
      );
    },
  );
  overlay.insert(entry);
}

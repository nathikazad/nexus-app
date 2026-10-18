import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mermaid_core/mermaid_core.dart' as core;
import 'package:mermaid_flutter/mermaid_flutter.dart';

const defaultMermaidSource = 'flowchart TD\n    A[Start] --> B[Next step]';

/// Shared native renderer: no network requests, browser, or platform channel.
class NxMermaidPreview extends StatelessWidget {
  const NxMermaidPreview({
    super.key,
    required this.source,
    this.interactive = false,
  });
  final String source;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final theme = MaterialMermaidTheme.fromTheme(Theme.of(context));
    Widget error(BuildContext context, Object error) => Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Text('Unable to render diagram.\n$error'),
      ),
    );
    if (source.trim().isEmpty) {
      return const Center(
        child: Text('Enter Mermaid source to preview a diagram.'),
      );
    }
    if (source.length > 30000) {
      return const Center(
        child: Text('Diagram source exceeds 30,000 characters.'),
      );
    }
    if (interactive) {
      return _InteractiveMermaid(source: source, errorBuilder: error);
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FittedBox(
        fit: BoxFit.contain,
        child: MermaidDiagram(
          source: source,
          theme: theme,
          semanticNodes: true,
          keepLastGoodSceneOnError: false,
          errorBuilder: error,
        ),
      ),
    );
  }
}

/// Owns the viewport so the controls can match the app's Material theme.
class _InteractiveMermaid extends StatefulWidget {
  const _InteractiveMermaid({required this.source, required this.errorBuilder});

  final String source;
  final Widget Function(BuildContext, Object) errorBuilder;

  @override
  State<_InteractiveMermaid> createState() => _InteractiveMermaidState();
}

class _InteractiveMermaidState extends State<_InteractiveMermaid> {
  final _transform = TransformationController();
  final _diagramKey = GlobalKey();
  Size _viewport = Size.zero;
  bool _needsFit = true;
  static const _minScale = 0.01;
  static const _maxScale = 8.0;

  @override
  void didUpdateWidget(covariant _InteractiveMermaid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _needsFit = true;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fit() {
    final box = _diagramKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty || _viewport.isEmpty) {
      return;
    }
    final scale = math
        .min(
          (_viewport.width - 40) / box.size.width,
          (_viewport.height - 40) / box.size.height,
        )
        .clamp(_minScale, _maxScale);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        (_viewport.width - box.size.width * scale) / 2,
        (_viewport.height - box.size.height * scale) / 2,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
    _needsFit = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_viewport != constraints.biggest) {
                _viewport = constraints.biggest;
                _needsFit = true;
              }
              if (_needsFit) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _needsFit) _fit();
                });
              }
              return ClipRect(
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: _minScale,
                  maxScale: _maxScale,
                  child: MermaidDiagram(
                    key: _diagramKey,
                    source: widget.source,
                    theme: MaterialMermaidTheme.fromTheme(Theme.of(context)),
                    semanticNodes: true,
                    keepLastGoodSceneOnError: false,
                    errorBuilder: widget.errorBuilder,
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: TextButton(
              onPressed: _fit,
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              child: const Text('Fit'),
            ),
          ),
        ),
      ],
    );
  }
}

/// A diagram-only view that fills the app window on every device.
class NxMermaidViewer extends StatelessWidget {
  const NxMermaidViewer({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Close',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('Mermaid diagram'),
    ),
    body: SafeArea(child: NxMermaidPreview(source: source, interactive: true)),
  );
}

/// Returns new source only on Save; closing leaves the document unchanged.
class NxMermaidEditor extends StatefulWidget {
  const NxMermaidEditor({
    super.key,
    required this.source,
    this.readOnly = false,
  });
  final String source;
  final bool readOnly;
  @override
  State<NxMermaidEditor> createState() => _NxMermaidEditorState();
}

class _NxMermaidEditorState extends State<NxMermaidEditor> {
  late final TextEditingController _controller;
  late String _preview;
  Timer? _debounce;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.source);
    _preview = widget.source;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _preview = value;
          _error = null;
        });
      }
    });
  }

  void _save() {
    final source = _controller.text;
    try {
      if (source.trim().isEmpty) {
        throw const FormatException('Enter a diagram before saving.');
      }
      if (source.length > 30000) {
        throw const FormatException(
          'Diagram source exceeds 30,000 characters.',
        );
      }
      const core.Mermaid(measurer: FlutterTextMeasurer()).render(source);
      Navigator.of(context).pop(source);
    } catch (error) {
      setState(() {
        _preview = source;
        _error = error.toString();
      });
    }
  }

  Widget _sourceField() => Padding(
    padding: const EdgeInsets.all(16),
    child: TextField(
      key: const ValueKey('mermaid-source'),
      controller: _controller,
      readOnly: widget.readOnly,
      expands: true,
      minLines: null,
      maxLines: null,
      maxLength: 30000,
      textAlignVertical: TextAlignVertical.top,
      autocorrect: false,
      enableSuggestions: false,
      smartQuotesType: SmartQuotesType.disabled,
      smartDashesType: SmartDashesType.disabled,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      decoration: const InputDecoration(
        labelText: 'Mermaid source',
        alignLabelWithHint: true,
        border: OutlineInputBorder(),
      ),
      onChanged: _changed,
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 720;
      final preview = NxMermaidPreview(source: _preview, interactive: true);
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(widget.readOnly ? 'Mermaid diagram' : 'Edit Mermaid'),
            actions: [
              if (!widget.readOnly)
                TextButton(onPressed: _save, child: const Text('Save')),
            ],
            bottom: narrow
                ? const TabBar(
                    tabs: [
                      Tab(text: 'Preview'),
                      Tab(text: 'Source'),
                    ],
                  )
                : null,
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: narrow
                      ? TabBarView(children: [preview, _sourceField()])
                      : Row(
                          children: [
                            Expanded(child: _sourceField()),
                            const VerticalDivider(width: 1),
                            Expanded(child: preview),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

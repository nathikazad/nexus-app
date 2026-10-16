import 'dart:async';

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
      return MermaidView(
        source: source,
        theme: theme,
        semanticNodes: true,
        keepLastGoodSceneOnError: false,
        errorBuilder: error,
        allowFullscreen: false,
      );
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

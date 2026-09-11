import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_documents/nx_documents.dart';
import 'package:nx_voice/nx_voice.dart';
import 'reading_companion_controller.dart';
import '../data/book/kgql_reading_history.dart';
import 'reading_companion_conversation.dart';
import '../data/providers.dart';
import '../data/offline/reading_history_store.dart';

class ReadingSelectionRequest {
  const ReadingSelectionRequest(this.identity, this.text);
  final DocumentIdentity identity;
  final String text;
}

final readingSelectionProvider =
    Provider<ValueNotifier<ReadingSelectionRequest?>>((ref) {
      final value = ValueNotifier<ReadingSelectionRequest?>(null);
      ref.onDispose(value.dispose);
      return value;
    });

class ReadingCompanion extends ConsumerStatefulWidget {
  const ReadingCompanion({required this.child, this.identity, super.key});
  final Widget child;
  final DocumentIdentity? identity;
  @override
  ConsumerState<ReadingCompanion> createState() => _ReadingCompanionState();
}

class _ReadingCompanionState extends ConsumerState<ReadingCompanion>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _layoutButtonLink = LayerLink();
  late final ValueNotifier<ReadingSelectionRequest?> _selectionRequests;
  ReadingCompanionController? _controller;
  bool _open = false;
  bool _layoutPickerOpen = false;
  bool _confirmClear = false;
  int _panelLayoutIndex = 0;
  bool _loading = false;
  String _title = '';
  String _selection = '';
  ReadingHistoryStore? _historyStore;
  Timer? _historySaveTimer;
  DocumentIdentity? _historyIdentity;

  void _saveHistory() {
    final controller = _controller;
    final identity = _historyIdentity;
    if (controller == null || identity == null || _loading) return;
    unawaited(
      _historyStore
          ?.save(identity, ReadingHistory(_title, List.of(controller.messages)))
          .catchError((Object _) {
            if (mounted && identical(controller, _controller)) {
              setState(
                () => controller.error =
                    'Could not save this conversation for offline use.',
              );
            }
          }),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectionRequests = ref.read(readingSelectionProvider)
      ..addListener(_selectionRequested);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A microphone permission dialog temporarily makes the app inactive.
    // Cancel only when actually backgrounded, not while granting permission.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_controller?.recording == true) unawaited(_controller?.cancel());
    }
  }

  @override
  void dispose() {
    _historySaveTimer?.cancel();
    _saveHistory();
    WidgetsBinding.instance.removeObserver(this);
    _selectionRequests.removeListener(_selectionRequested);
    _controller?.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReadingCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _historySaveTimer?.cancel();
      _saveHistory();
      _controller?.removeListener(_changed);
      _controller?.dispose();
      _controller = null;
      _loading = false;
      _open = false;
      _title = '';
      _selection = '';
      _input.clear();
    }
  }

  Future<void> _show() async {
    setState(() {
      _open = true;
      final selected = _selectionRequests.value;
      _selection = selected != null && selected.identity == widget.identity
          ? selected.text
          : '';
    });
    if (_controller != null || _loading || widget.identity == null) return;
    final user = ref.read(authProvider).value;
    final url = ref.read(sockWsUrlProvider);
    if (user == null || url == null) return;
    final identity = widget.identity!;
    _historyIdentity = identity;
    final controller = ReadingCompanionController(
      hasNetwork: ref.read(booksNetworkAvailableProvider),
      config: DocumentAiSessionConfig(
        socketUrl: url,
        userId: user.userId,
        documentId: identity.id,
        clientApp: 'nx_books',
        agentId: 'nx_books',
        authHeaders: (refresh) =>
            nexusAuthHeaders(user.preset, user.userId, forceRefresh: refresh),
      ),
    );
    _historyStore = ref.read(readingHistoryStoreProvider);
    controller.addListener(_changed);
    setState(() {
      _controller = controller;
      _loading = true;
    });
    try {
      final cached = await _historyStore?.load(identity);
      if (!mounted || !identical(controller, _controller)) return;
      if (cached != null) {
        _title = cached.title;
        controller.messages.addAll(cached.messages);
        return;
      }
      if (!await ref.read(booksNetworkAvailableProvider)()) {
        controller.error =
            'No saved conversation for this chapter. Connect and use Sync now before travelling. New AI replies require internet.';
        return;
      }
      final history = await fetchReadingHistory(
        ref.read(graphqlClientProvider),
        identity,
      );
      if (!mounted || !identical(controller, _controller)) return;
      _title = history.title;
      controller.messages.addAll(history.messages);
    } catch (_) {
      if (mounted && identical(controller, _controller)) {
        controller.error =
            'History is unavailable. You can still try sending a question.';
      }
    } finally {
      if (mounted && identical(controller, _controller)) {
        setState(() => _loading = false);
        _saveHistory();
      }
    }
  }

  void _selectionRequested() {
    final selected = _selectionRequests.value;
    if (selected == null || selected.identity != widget.identity) return;
    unawaited(_show());
  }

  Future<void> _syncHistory() async {
    final controller = _controller;
    final identity = widget.identity;
    if (_loading || controller == null || identity == null) return;
    final client = ref.read(graphqlClientProvider);
    final hasNetwork = ref.read(booksNetworkAvailableProvider);
    _historySaveTimer?.cancel();
    setState(() => _loading = true);
    final history = await controller.syncHistory(() async {
      if (!await hasNetwork()) throw StateError('Offline');
      return fetchReadingHistory(client, identity);
    });
    if (!mounted || !identical(controller, _controller)) return;
    setState(() {
      if (history != null) _title = history.title;
      _loading = false;
    });
    if (history != null) _saveHistory();
  }

  void _changed() {
    _historySaveTimer?.cancel();
    if (_controller?.busy == true) {
      _historySaveTimer = Timer(
        const Duration(milliseconds: 500),
        _saveHistory,
      );
    } else {
      _saveHistory();
    }
    if (mounted) setState(() {});
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_controller?.recording == true) unawaited(_controller?.cancel());
    setState(() => _open = false);
  }

  Future<void> _clearTranscript() async {
    final controller = _controller;
    final identity = widget.identity;
    if (controller == null || identity == null) return;
    setState(() {
      _confirmClear = false;
      _loading = true;
    });
    final client = ref.read(graphqlClientProvider);
    final cleared = await controller.clearTranscript(() async {
      // Resolve fresh: the first reply may have created the transcript since
      // this panel was opened. Clear only transcripts linked to this document.
      final rows = await fetchKgqlModels(
        client,
        filter: {
          'model_type': identity.modelType,
          'filters': [
            {'key': 'id', 'op': '=', 'value': '${identity.id}'},
          ],
        },
        struct: const {
          'id': true,
          'Transcript': {'id': true},
        },
      );
      if (rows.isEmpty) throw StateError('Document not found');
      for (final transcript in rows.first.relations?['Transcript'] ?? []) {
        await setKgqlModel(
          client,
          SetModelRequest(
            id: transcript.id,
            attributes: [
              SetModelAttribute(key: 'messages', value: <String, dynamic>{}),
            ],
          ),
        );
      }
      await _historyStore?.save(identity, ReadingHistory(_title, const []));
    });
    if (!mounted || !identical(controller, _controller)) return;
    setState(() {
      _loading = false;
      if (cleared) {
        _input.clear();
        _selection = '';
        _selectionRequests.value = null;
      }
    });
    if (cleared) _saveHistory();
  }

  Future<void> _send() async {
    final original = _input.text;
    final sent =
        await _controller?.send(original, selection: _selection) ?? false;
    if (mounted && sent) {
      if (_input.text == original) _input.clear();
      setState(() => _selection = '');
      _selectionRequests.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, bounds) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final usableHeight = math.max(
          0.0,
          bounds.maxHeight - keyboard - MediaQuery.paddingOf(context).top,
        );
        final layout = PanelLayout.values[_panelLayoutIndex];
        final floatingWidth = math.max(0.0, bounds.maxWidth - 24);
        final floatingHeight = math.max(0.0, usableHeight - 24);
        final (width, height) = switch (layout) {
          PanelLayout.compact => (
            math.min(floatingWidth, 400.0),
            math.min(floatingHeight, 540.0),
          ),
          PanelLayout.expanded => (
            math.min(floatingWidth, 560.0),
            math.min(floatingHeight, 760.0),
          ),
          PanelLayout.bottom => (
            bounds.maxWidth,
            math.min(usableHeight, math.max(420.0, usableHeight * 0.46)),
          ),
          PanelLayout.right => (math.min(bounds.maxWidth, 560.0), usableHeight),
          PanelLayout.fullScreen => (bounds.maxWidth, usableHeight),
        };
        final docked =
            layout == PanelLayout.bottom ||
            layout == PanelLayout.right ||
            layout == PanelLayout.fullScreen;
        return Stack(
          children: [
            widget.child,
            if (!_open)
              Positioned(
                right: 16,
                bottom: keyboard + 16 + MediaQuery.paddingOf(context).bottom,
                child: FloatingActionButton.small(
                  heroTag: 'reading-companion',
                  tooltip: 'Reading companion',
                  onPressed: _show,
                  child: const Icon(Icons.auto_awesome_outlined),
                ),
              ),
            if (_open && height > 0)
              Positioned(
                right: docked ? 0 : 12,
                bottom: keyboard + (docked ? 0 : 12),
                width: width,
                height: height,
                child: Material(
                  key: const ValueKey('reading-companion-panel'),
                  elevation: 12,
                  color: colors.surface,
                  borderRadius: layout == PanelLayout.fullScreen
                      ? BorderRadius.zero
                      : BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 16),
                          const Expanded(child: Text('Reading companion')),
                          if (widget.identity != null)
                            IconButton(
                              tooltip: 'Sync conversation',
                              onPressed:
                                  _loading ||
                                      controller == null ||
                                      controller.recording
                                  ? null
                                  : _syncHistory,
                              icon: controller?.syncing == true
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync),
                            ),
                          CompositedTransformTarget(
                            key: const ValueKey('panel-layout-button-anchor'),
                            link: _layoutButtonLink,
                            child: IconButton(
                              tooltip: 'Change panel layout',
                              onPressed: () => setState(
                                () => _layoutPickerOpen = !_layoutPickerOpen,
                              ),
                              icon: PanelLayoutIcon(layout: layout),
                            ),
                          ),
                          if (widget.identity != null)
                            IconButton(
                              tooltip: 'Clear conversation',
                              onPressed:
                                  _loading ||
                                      controller == null ||
                                      controller.busy ||
                                      controller.recording
                                  ? null
                                  : () {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      setState(() => _confirmClear = true);
                                    },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          IconButton(
                            tooltip: 'Close companion',
                            onPressed: _close,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      if (widget.identity == null)
                        const Expanded(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Open a book or chapter to discuss it here.',
                              ),
                            ),
                          ),
                        )
                      else ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Saved history is available offline. New AI replies require internet.',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _selection.isNotEmpty
                                  ? 'Selected passage · ${_title.isEmpty ? widget.identity!.modelType : _title}'
                                  : 'Current document · ${_title.isEmpty ? "${widget.identity!.modelType} #${widget.identity!.id}" : _title}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ),
                        if (_selection.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selection,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Clear selected passage',
                                  onPressed: () {
                                    setState(() => _selection = '');
                                    _selectionRequests.value = null;
                                  },
                                  icon: const Icon(Icons.close, size: 16),
                                ),
                              ],
                            ),
                          ),
                        const Divider(),
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : controller == null
                              ? const Center(
                                  child: Text('Sign in to use the companion.'),
                                )
                              : controller.messages.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text(
                                      'Ask a question, or tap the microphone to record. Tap stop to send.\n\nTry “Explain the main idea with an example.”',
                                    ),
                                  ),
                                )
                              : ReadingCompanionConversation(
                                  messages: controller.messages,
                                  busy: controller.busy,
                                ),
                        ),
                        if (controller?.error case final error?)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              error,
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                        if (controller?.busy == true)
                          const LinearProgressIndicator(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  controller?.recording == true
                                      ? 'Recording… tap stop to send'
                                      : controller?.busy == true
                                      ? 'Working…'
                                      : 'Tap mic to record · up to 60s · text replies',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                              if (controller?.busy == true ||
                                  controller?.recording == true)
                                IconButton(
                                  tooltip: 'Cancel turn',
                                  onPressed: _loading
                                      ? null
                                      : controller!.cancel,
                                  icon: const Icon(Icons.close),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 8, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: ReadingQuestionField(
                                  controller: _input,
                                  enabled:
                                      !_loading &&
                                      controller != null &&
                                      !controller.recording,
                                  onSubmitted: (_) => _send(),
                                ),
                              ),
                              ReadingMicrophoneButton(
                                controller: controller,
                                enabled: !_loading,
                                selection: _selection,
                              ),
                              IconButton(
                                tooltip: 'Send question',
                                onPressed:
                                    _loading ||
                                        controller == null ||
                                        controller.busy ||
                                        controller.recording
                                    ? null
                                    : _send,
                                icon: const Icon(Icons.arrow_upward),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (_layoutPickerOpen || _confirmClear)
              Positioned.fill(
                child: ModalBarrier(
                  color: Colors.black26,
                  dismissible: true,
                  onDismiss: () => setState(() {
                    _layoutPickerOpen = false;
                    _confirmClear = false;
                  }),
                ),
              ),
            if (_layoutPickerOpen)
              Positioned(
                left: 0,
                top: 0,
                width: 48.0 * PanelLayout.values.length,
                height: 48,
                child: CompositedTransformFollower(
                  link: _layoutButtonLink,
                  targetAnchor: Alignment.bottomRight,
                  followerAnchor: Alignment.topRight,
                  showWhenUnlinked: false,
                  child: Material(
                    key: const ValueKey('panel-layout-picker'),
                    elevation: 16,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        for (final option in PanelLayout.values)
                          IconButton(
                            tooltip: option.label,
                            isSelected: option == layout,
                            onPressed: () => setState(() {
                              _panelLayoutIndex = option.index;
                              _layoutPickerOpen = false;
                            }),
                            icon: PanelLayoutIcon(layout: option),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_confirmClear)
              Positioned.fill(
                child: Center(
                  child: AlertDialog(
                    title: const Text('Clear this conversation?'),
                    content: const Text(
                      'Remove all messages for this book or chapter from this app and the saved database transcript. This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _confirmClear = false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: _clearTranscript,
                        child: const Text('Clear conversation'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ReadingMicrophoneButton extends StatelessWidget {
  const ReadingMicrophoneButton({
    required this.controller,
    this.enabled = true,
    this.selection = '',
    super.key,
  });

  final ReadingCompanionController? controller;
  final bool enabled;
  final String selection;

  @override
  Widget build(BuildContext context) {
    final recording = controller?.recording == true;
    return IconButton(
      tooltip: recording ? 'Stop recording and send' : 'Record a question',
      onPressed: !enabled || controller == null || controller!.busy
          ? null
          : () {
              if (recording) {
                unawaited(controller!.stopRecording());
              } else {
                FocusManager.instance.primaryFocus?.unfocus();
                unawaited(controller!.startRecording(selection: selection));
              }
            },
      icon: Icon(recording ? Icons.stop_circle : Icons.mic_none),
      color: recording ? Theme.of(context).colorScheme.error : null,
    );
  }
}

enum PanelLayout {
  compact('Compact panel'),
  expanded('Expanded panel'),
  bottom('Full-width bottom panel'),
  right('Full-height right panel'),
  fullScreen('Full-screen panel');

  const PanelLayout(this.label);
  final String label;
}

class PanelLayoutIcon extends StatelessWidget {
  const PanelLayoutIcon({required this.layout, super.key});

  final PanelLayout layout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomPaint(
      size: const Size.square(24),
      painter: _PanelLayoutIconPainter(
        layout: layout,
        color: colors.onSurfaceVariant,
        fillColor: colors.primary,
      ),
    );
  }
}

class _PanelLayoutIconPainter extends CustomPainter {
  const _PanelLayoutIconPainter({
    required this.layout,
    required this.color,
    required this.fillColor,
  });

  final PanelLayout layout;
  final Color color;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(2)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final panel = switch (layout) {
      PanelLayout.compact => Rect.fromLTWH(13, 12, 7, 8),
      PanelLayout.expanded => Rect.fromLTWH(10, 8, 10, 12),
      PanelLayout.bottom => Rect.fromLTWH(2, 13, 20, 9),
      PanelLayout.right => Rect.fromLTWH(11, 2, 11, 20),
      PanelLayout.fullScreen => Rect.fromLTWH(2, 2, 20, 20),
    };
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(1.5)),
      Paint()..color = fillColor.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_PanelLayoutIconPainter oldDelegate) =>
      layout != oldDelegate.layout ||
      color != oldDelegate.color ||
      fillColor != oldDelegate.fillColor;
}

class ReadingQuestionField extends TextField {
  ReadingQuestionField({
    required TextEditingController controller,
    super.enabled,
    super.focusNode,
    super.onSubmitted,
    super.key,
  }) : super(
         controller: controller,
         // Avoid stale predictive composing text returning after backspace
         // on the tablet's Gboard keyboard. Do not rewrite composing ranges.
         autocorrect: false,
         enableSuggestions: false,
         minLines: 1,
         maxLines: 3,
         textInputAction: TextInputAction.send,
         decoration: InputDecoration(
           hintText: 'Ask about this…',
           suffixIcon: IconButton(
             tooltip: 'Clear question and dismiss keyboard',
             onPressed: () {
               controller.clear();
               FocusManager.instance.primaryFocus?.unfocus();
             },
             icon: const Icon(Icons.clear),
           ),
         ),
       );
}

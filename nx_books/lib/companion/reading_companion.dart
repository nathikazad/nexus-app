import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_documents/nx_documents.dart';
import 'package:nx_voice/nx_voice.dart';
import 'reading_companion_controller.dart';

final readingSelectionProvider =
    Provider<ValueNotifier<(DocumentIdentity?, String)>>((ref) {
      final value = ValueNotifier<(DocumentIdentity?, String)>((null, ''));
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
  ReadingCompanionController? _controller;
  bool _open = false;
  bool _expanded = false;
  bool _loading = false;
  String _title = '';
  String _selection = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_controller?.cancel());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    setState(() {
      _open = true;
      final selected = ref.read(readingSelectionProvider).value;
      _selection = selected.$1 == widget.identity ? selected.$2 : '';
    });
    if (_controller != null || _loading || widget.identity == null) return;
    final user = ref.read(authProvider).value;
    final url = ref.read(sockWsUrlProvider);
    if (user == null || url == null) return;
    final identity = widget.identity!;
    final controller = ReadingCompanionController(
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
    controller.addListener(_changed);
    setState(() {
      _controller = controller;
      _loading = true;
    });
    try {
      final rows = await fetchKgqlModels(
        ref.read(graphqlClientProvider),
        filter: {
          'model_type': identity.modelType,
          'filters': [
            {'key': 'id', 'op': '=', 'value': '${identity.id}'},
          ],
        },
        struct: const {
          'id': true,
          'name': true,
          'Transcript': {'id': true, 'messages': true},
        },
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (rows.isNotEmpty) {
        _title = rows.first.name;
        final transcripts = rows.first.relations?['Transcript'];
        if (transcripts != null && transcripts.isNotEmpty) {
          dynamic history = transcripts.first.attributes?['messages'];
          if (history is String) history = jsonDecode(history);
          if (history is Map) {
            final entries = history.entries.toList()
              ..sort((a, b) => '${a.key}'.compareTo('${b.key}'));
            for (final entry in entries.skip(
              math.max(0, entries.length - 60),
            )) {
              final value = entry.value;
              if (value is! Map || value['message'] is! String) continue;
              final sender = value['sender'];
              if (sender == 'system') continue;
              controller.messages.add(
                ReadingMessage(
                  sender == 'agent' || sender == 'assistant'
                      ? 'assistant'
                      : 'user',
                  value['message'] as String,
                  turn: '${entry.key}',
                ),
              );
            }
          }
        }
      }
    } catch (_) {
      if (mounted) {
        controller.error =
            'History is unavailable. You can still try sending a question.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(_controller?.cancel());
    setState(() => _open = false);
  }

  Future<void> _send() async {
    final original = _input.text;
    final sent =
        await _controller?.send(original, selection: _selection) ?? false;
    if (mounted && sent && _input.text == original) _input.clear();
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
        final width = math.min(bounds.maxWidth - 24, _expanded ? 560.0 : 400.0);
        final height = math.min(usableHeight - 24, _expanded ? 760.0 : 540.0);
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
                right: 12,
                bottom: keyboard + 12,
                width: width,
                height: height,
                child: Material(
                  elevation: 12,
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 16),
                          const Expanded(child: Text('Reading companion')),
                          IconButton(
                            tooltip: _expanded ? 'Make smaller' : 'Expand',
                            onPressed: () =>
                                setState(() => _expanded = !_expanded),
                            icon: Icon(
                              _expanded
                                  ? Icons.close_fullscreen
                                  : Icons.open_in_full,
                            ),
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
                                  onPressed: () =>
                                      setState(() => _selection = ''),
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
                                      'Ask a question, or hold the microphone to talk.\n\nTry “Explain the main idea with an example.”',
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  reverse: true,
                                  padding: const EdgeInsets.all(12),
                                  itemCount: controller.messages.length,
                                  itemBuilder: (context, index) {
                                    final message =
                                        controller.messages[controller
                                                .messages
                                                .length -
                                            1 -
                                            index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message.role == 'user'
                                                ? 'You'
                                                : 'Companion',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                          SelectableText(message.text),
                                        ],
                                      ),
                                    );
                                  },
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
                              IconButton(
                                tooltip: controller?.speakReplies == true
                                    ? 'Mute spoken replies'
                                    : 'Speak replies',
                                onPressed: controller == null
                                    ? null
                                    : () => controller.setSpeakReplies(
                                        !controller.speakReplies,
                                      ),
                                icon: Icon(
                                  controller?.speakReplies == true
                                      ? Icons.volume_up_outlined
                                      : Icons.volume_off_outlined,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  controller?.recording == true
                                      ? 'Recording… release to send'
                                      : controller?.busy == true
                                      ? 'Working…'
                                      : 'Hold mic to talk · up to 60s',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                              if (controller?.busy == true ||
                                  controller?.recording == true)
                                IconButton(
                                  tooltip: 'Cancel turn',
                                  onPressed: controller!.cancel,
                                  icon: const Icon(Icons.stop_circle_outlined),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 8, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  enabled:
                                      !_loading &&
                                      controller != null &&
                                      !controller.recording,
                                  minLines: 1,
                                  maxLines: 3,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _send(),
                                  decoration: const InputDecoration(
                                    hintText: 'Ask about this…',
                                  ),
                                ),
                              ),
                              Semantics(
                                label: 'Hold to record a question',
                                button: true,
                                child: GestureDetector(
                                  onLongPressStart:
                                      !_loading && controller != null
                                      ? (_) => controller.startRecording()
                                      : null,
                                  onLongPressEnd: (_) =>
                                      controller?.stopRecording(),
                                  onLongPressCancel: () =>
                                      controller?.stopRecording(),
                                  child: Tooltip(
                                    message: 'Hold to talk; release to send',
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Icon(
                                        controller?.recording == true
                                            ? Icons.mic
                                            : Icons.mic_none,
                                        color: controller?.recording == true
                                            ? colors.error
                                            : colors.primary,
                                      ),
                                    ),
                                  ),
                                ),
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
          ],
        );
      },
    );
  }
}

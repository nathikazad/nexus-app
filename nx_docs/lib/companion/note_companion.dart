import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_live_agent/nx_live_agent.dart';
import 'package:nx_docs/books/book_providers.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/workspace/layout.dart';
import 'package:nx_docs/companion/companion_providers.dart';
import 'package:nx_docs/documents/assets/document_audio_service.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/companion/conversation_reference.dart';
import 'package:nx_docs/books/book_conversation_picker.dart';
import 'package:nx_docs/companion/note_companion_controller.dart';
import 'package:nx_docs/companion/conversation/conversation_coordinator.dart';
import 'package:nx_docs/companion/conversation/conversation_policy.dart';
import 'package:nx_docs/companion/conversation/live_conversation_page.dart';
import 'package:nx_docs/companion/conversation/live_conversation_floating_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'companion_audio.dart';
part 'companion_view.dart';

const notePlaybackSpeeds = <double>[0.75, 1, 1.25, 1.5, 2];
const _notePlaybackSpeedPreferenceKey = 'nx_notes.note_playback_speed';

class NoteCompanion extends ConsumerStatefulWidget {
  const NoteCompanion({
    required this.document,
    this.onAudioBlockChanged,
    this.embeddedChat = false,
    this.voiceEnabled = true,
    super.key,
  });

  final NxDocument document;
  final ValueChanged<DocumentAudioBlockTiming>? onAudioBlockChanged;
  final bool embeddedChat;
  final bool voiceEnabled;

  @override
  ConsumerState<NoteCompanion> createState() => _NoteCompanionState();
}

class _NoteCompanionState extends ConsumerState<NoteCompanion> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  NoteCompanionController? _controller;
  NoteLiveConversationCoordinator? _liveCoordinator;
  bool _chatExpanded = false;
  bool _audioExpanded = false;
  bool _bookChapterPickerActive = false;
  bool _embeddedHistoryRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureController();
    _ensureLiveCoordinator();
  }

  @override
  void didUpdateWidget(covariant NoteCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _replaceController();
      _chatExpanded = false;
      _audioExpanded = false;
      _bookChapterPickerActive = false;
      _embeddedHistoryRequested = false;
    }
  }

  void _ensureLiveCoordinator() {
    if (_liveCoordinator != null) return;
    final coordinator = ref.read(noteLiveConversationCoordinatorProvider);
    coordinator.addListener(_onLiveCoordinatorChanged);
    _liveCoordinator = coordinator;
  }

  void _ensureController() {
    if (_controller != null) return;
    final socketUrl = ref.read(sockWsUrlProvider);
    final userId = ref.read(userIdProvider);
    final baseUrl = ref.read(imageBaseUrlProvider);
    if (socketUrl == null ||
        baseUrl == null ||
        userId == null ||
        userId.isEmpty) {
      return;
    }
    final httpClient = ref.read(nexusHttpClientProvider);
    if (httpClient == null) return;
    final audioService = DocumentAudioService(
      baseUrl: baseUrl,
      userId: userId,
      client: httpClient,
    );
    final initialAudio = widget.document.audio;
    final controller = NoteCompanionController(
      documentId: widget.document.id,
      socketUrl: socketUrl,
      userId: userId,
      audioService: audioService,
      transcriptLoader: ref.read(noteTranscriptLoaderProvider),
      authHeaders: () {
        final user = ref.read(authProvider).value;
        if (user == null) return Future.value({'x-user-id': userId});
        return nexusAuthHeaders(user.preset, userId);
      },
      initialAudio: initialAudio == null
          ? null
          : DocumentAudio(
              url: audioService.resolveUrl(initialAudio.url),
              sourceHash: initialAudio.sourceHash,
              manifest: initialAudio.manifest,
            ),
      initialBlockKey: _scrollAnchorBlockKey(widget.document.jsonDocument),
      onAudioBlockChanged: widget.onAudioBlockChanged,
    )..addListener(_onControllerChanged);
    _controller = controller;
    unawaited(_restorePlaybackSpeed(controller));
    _loadEmbeddedHistory();
  }

  Future<void> _restorePlaybackSpeed(NoteCompanionController controller) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final speed = preferences.getDouble(_notePlaybackSpeedPreferenceKey);
      if (speed != null &&
          notePlaybackSpeeds.contains(speed) &&
          mounted &&
          identical(controller, _controller)) {
        await controller.setNoteAudioPlaybackSpeed(speed);
      }
    } catch (_) {
      // Playback remains at 1x if preferences are unavailable.
    }
  }

  void _loadEmbeddedHistory() {
    final controller = _controller;
    if (!widget.embeddedChat ||
        controller == null ||
        _embeddedHistoryRequested) {
      return;
    }
    _embeddedHistoryRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(controller, _controller)) {
        unawaited(controller.loadHistory());
      }
    });
  }

  void _replaceController() {
    final previous = _controller;
    _controller = null;
    if (previous != null) {
      previous.removeListener(_onControllerChanged);
      previous.dispose();
    }
    _ensureController();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onLiveCoordinatorChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _liveCoordinator?.removeListener(_onLiveCoordinatorChanged);
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(noteLiveConversationCoordinatorProvider);
    final controller = _controller;
    final liveCoordinator = _liveCoordinator;
    final Widget content;
    if (widget.embeddedChat) {
      _loadEmbeddedHistory();
      content = _buildChatPanel(
        controller,
        height: double.infinity,
        embedded: true,
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final chatHeight = constraints.hasBoundedHeight
              ? (constraints.maxHeight - 72).clamp(300.0, 760.0)
              : (MediaQuery.sizeOf(context).height - 190).clamp(300.0, 760.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (_chatExpanded)
                _buildChatPanel(controller, height: chatHeight),
              if (_audioExpanded && controller != null)
                _AudioPanel(
                  controller: controller,
                  onClose: () => setState(() => _audioExpanded = false),
                ),
              if (_chatExpanded || _audioExpanded) const SizedBox(height: 8),
              if (!_chatExpanded &&
                  liveCoordinator?.isActive == true &&
                  liveCoordinator?.controller != null)
                LiveConversationFloatingControls(
                  controller: liveCoordinator!.controller!,
                  layout: LiveConversationPlatformPolicy.controlsFor(
                    defaultTargetPlatform,
                  ),
                  stopping: liveCoordinator.isStopping,
                  onStop: _stopLiveConversation,
                  heroPrefix: 'note-live-${widget.document.id}',
                )
              else if (liveCoordinator?.isActive != true)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Tooltip(
                      message: controller?.hasAudio == true
                          ? 'Open note playback'
                          : 'Create note audio',
                      child: FloatingActionButton.small(
                        heroTag: 'note-audio-${widget.document.id}',
                        elevation: 2,
                        backgroundColor: AppColors.floating,
                        foregroundColor: AppColors.onFloating,
                        onPressed:
                            controller == null || controller.generatingAudio
                            ? null
                            : () => unawaited(_toggleAudio(controller)),
                        child: controller?.generatingAudio == true
                            ? const SizedBox.square(
                                dimension: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                controller?.noteAudioPlaying == true
                                    ? Icons.pause_rounded
                                    : Icons.headphones_rounded,
                                size: 18,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Open note AI',
                      child: Tooltip(
                        message: 'Ask AI about this note',
                        child: FloatingActionButton.small(
                          heroTag: 'note-companion-${widget.document.id}',
                          elevation: 2,
                          backgroundColor: AppColors.floating,
                          foregroundColor: AppColors.onFloating,
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            final opening = !_chatExpanded;
                            setState(() {
                              _chatExpanded = opening;
                              if (_chatExpanded) _audioExpanded = false;
                            });
                            if (opening && controller != null) {
                              unawaited(controller.loadHistory());
                            }
                          },
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      );
    }
    return TapRegion(
      onTapOutside: !widget.embeddedChat && !isDesktopLayout(context)
          ? (_) {
              if (!_chatExpanded) return;
              FocusScope.of(context).unfocus();
              setState(() {
                _chatExpanded = false;
                _bookChapterPickerActive = false;
              });
            }
          : null,
      child: Theme(
        data: _neutralCompanionTheme(Theme.of(context)),
        child: content,
      ),
    );
  }

  Widget _buildChatPanel(
    NoteCompanionController? controller, {
    required double height,
    bool embedded = false,
  }) {
    final content = Column(
      children: <Widget>[
        if (!embedded)
          _CompanionHeader(
            phase: controller?.phase ?? NoteCompanionPhase.idle,
            onClose: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _chatExpanded = false;
                _bookChapterPickerActive = false;
              });
            },
          ),
        if (_liveCoordinator?.hasConversation == true)
          Expanded(
            child: NoteLiveConversationPanel(
              coordinator: _liveCoordinator!,
              onEnd: () {
                _liveCoordinator?.dismissRecap();
              },
            ),
          )
        else if (controller == null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  'Sign in to ask questions about this note.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ),
          )
        else if (_bookChapterPickerActive)
          Expanded(
            child: BookChapterConversationPicker(
              bookId: widget.document.id,
              repository: ref.read(bookChapterRepositoryProvider),
              onCancel: () {
                if (mounted) {
                  setState(() => _bookChapterPickerActive = false);
                }
              },
              onStart: (references) {
                if (mounted) {
                  unawaited(_beginLiveConversation(references));
                }
              },
            ),
          )
        else ...<Widget>[
          if (controller.loadingHistory && controller.messages.isEmpty)
            const Expanded(
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (controller.messages.isEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'Ask anything about this note.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: _MessageList(
                messages: controller.messages,
                hasOlderMessages: controller.hasOlderMessages,
                loadingOlder: controller.loadingHistory,
                onLoadOlder: controller.loadOlderMessages,
              ),
            ),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      controller.error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.red, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    onPressed: controller.clearError,
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          _Composer(
            controller: controller,
            textController: _textController,
            focusNode: _textFocusNode,
            onSubmit: _submitText,
            onStartLiveConversation: _startLiveConversation,
            voiceEnabled: widget.voiceEnabled,
          ),
        ],
      ],
    );
    if (embedded) {
      return ColoredBox(
        key: const ValueKey<String>('note-companion-embedded-chat'),
        color: AppColors.panel,
        child: content,
      );
    }
    return Material(
      color: AppColors.panel,
      elevation: 8,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        key: const ValueKey<String>('note-companion-chat-panel'),
        width: (MediaQuery.sizeOf(context).width - 24).clamp(280, 420),
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: content,
      ),
    );
  }

  Future<void> _toggleAudio(NoteCompanionController controller) async {
    if (!controller.hasAudio) {
      await controller.generateAudio();
      if (!mounted || !controller.hasAudio) return;
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _audioExpanded = !_audioExpanded;
      if (_audioExpanded) _chatExpanded = false;
    });
  }

  void _submitText() {
    final controller = _controller;
    final text = _textController.text.trim();
    if (controller == null || text.isEmpty) return;
    _textController.clear();
    unawaited(controller.sendText(text));
  }

  void _startLiveConversation() {
    FocusScope.of(context).unfocus();
    if (widget.document.isBook) {
      setState(() {
        _bookChapterPickerActive = true;
      });
      return;
    }
    unawaited(_beginLiveConversation(const <ConversationReference>[]));
  }

  Future<void> _beginLiveConversation(
    List<ConversationReference> references,
  ) async {
    final coordinator = _liveCoordinator;
    if (coordinator == null || coordinator.hasConversation) return;
    final started = coordinator.start(
      document: widget.document,
      references: references,
    );
    setState(() {
      _bookChapterPickerActive = false;
    });
    await started;
    if (!mounted || widget.embeddedChat) return;
    setState(() {
      _chatExpanded = coordinator.controller?.phase == LiveAgentPhase.error;
    });
  }

  Future<void> _stopLiveConversation() async {
    final coordinator = _liveCoordinator;
    if (coordinator == null) return;
    await coordinator.stop();
    if (!mounted) return;
    setState(() {
      _chatExpanded = true;
      _audioExpanded = false;
    });
  }
}

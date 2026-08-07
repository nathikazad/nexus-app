import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/data/ai/note_transcript_service.dart';
import 'package:nx_notes/data/document/document_audio_service.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_audio.dart';
import 'package:nx_notes/features/companion/note_companion_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _chatExpanded = false;
  bool _audioExpanded = false;
  bool _embeddedHistoryRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureController();
  }

  @override
  void didUpdateWidget(covariant NoteCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _replaceController();
      _chatExpanded = false;
      _audioExpanded = false;
      _embeddedHistoryRequested = false;
    }
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
    final audioService = DocumentAudioService(baseUrl: baseUrl, userId: userId);
    final initialAudio = widget.document.audio;
    final controller = NoteCompanionController(
      documentId: widget.document.id,
      socketUrl: socketUrl,
      userId: userId,
      audioService: audioService,
      transcriptLoader: NoteTranscriptService(
        client: ref.read(graphqlClientProvider),
      ),
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

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                        child: const Icon(Icons.auto_awesome_rounded, size: 18),
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
    return Theme(
      data: _neutralCompanionTheme(Theme.of(context)),
      child: content,
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
              setState(() => _chatExpanded = false);
            },
          ),
        if (controller == null)
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
}

class _AudioPanel extends StatelessWidget {
  const _AudioPanel({required this.controller, required this.onClose});

  final NoteCompanionController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      elevation: 8,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: (MediaQuery.sizeOf(context).width - 24).clamp(280, 380),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 7, 8, 0),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.headphones_rounded,
                    size: 16,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note playback',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Minimize playback',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            _AudioControls(controller: controller),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 8),
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
                      tooltip: 'Dismiss error',
                      visualDensity: VisualDensity.compact,
                      onPressed: controller.clearError,
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AudioControls extends StatelessWidget {
  const _AudioControls({required this.controller});

  final NoteCompanionController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasAudio) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: controller.generatingAudio
                ? null
                : () => unawaited(controller.generateAudio()),
            icon: controller.generatingAudio
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.headphones_rounded, size: 18),
            label: Text(
              controller.generatingAudio ? 'Creating audio…' : 'Create audio',
            ),
          ),
        ),
      );
    }
    final durationMs = controller.audioDuration.inMilliseconds;
    final positionMs = controller.audioPosition.inMilliseconds.clamp(
      0,
      durationMs,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 4),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: controller.loadingNoteAudio
                ? 'Loading audio'
                : controller.noteAudioPlaying
                ? 'Pause note'
                : 'Play note',
            onPressed: controller.loadingNoteAudio
                ? null
                : () => unawaited(controller.toggleNoteAudio()),
            icon: controller.loadingNoteAudio
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    controller.noteAudioPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
          ),
          Expanded(
            child: Slider(
              value: durationMs <= 0 ? 0 : positionMs.toDouble(),
              max: durationMs <= 0 ? 1 : durationMs.toDouble(),
              onChanged: durationMs <= 0
                  ? null
                  : (value) => unawaited(
                      controller.seekNoteAudio(
                        Duration(milliseconds: value.round()),
                      ),
                    ),
            ),
          ),
          Text(
            _formatDuration(controller.audioPosition),
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          NotePlaybackSpeedButton(
            speed: controller.noteAudioPlaybackSpeed,
            onSelected: (speed) async {
              await controller.setNoteAudioPlaybackSpeed(speed);
              if (controller.noteAudioPlaybackSpeed != speed) return;
              try {
                final preferences = await SharedPreferences.getInstance();
                await preferences.setDouble(
                  _notePlaybackSpeedPreferenceKey,
                  speed,
                );
              } catch (_) {
                // The selected speed still applies for this app session.
              }
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Audio options',
            onSelected: (_) =>
                unawaited(controller.generateAudio(overwrite: true)),
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'regenerate',
                child: Text('Regenerate audio'),
              ),
            ],
            icon: const Icon(Icons.more_horiz_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class NotePlaybackSpeedButton extends StatelessWidget {
  const NotePlaybackSpeedButton({
    required this.speed,
    required this.onSelected,
    super.key,
  });

  final double speed;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      key: const ValueKey<String>('note-playback-speed-button'),
      tooltip: 'Playback speed',
      initialValue: speed,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      offset: const Offset(-112, -224),
      color: Colors.black,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black54,
      elevation: 10,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      constraints: const BoxConstraints.tightFor(width: 124),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xff3f3f46)),
      ),
      itemBuilder: (_) => <PopupMenuEntry<double>>[
        for (final option in notePlaybackSpeeds)
          PopupMenuItem<double>(
            key: ValueKey<String>('note-playback-speed-$option'),
            value: option,
            height: 38,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: option == speed
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  formatNotePlaybackSpeed(option),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: option == speed
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
        child: Text(
          formatNotePlaybackSpeed(speed),
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String formatNotePlaybackSpeed(double speed) =>
    '${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2).replaceFirst(RegExp(r'0$'), '')}×';

ThemeData _neutralCompanionTheme(ThemeData base) {
  final scheme = base.colorScheme.copyWith(
    primary: AppColors.text,
    onPrimary: AppColors.panel,
    primaryContainer: AppColors.subtle,
    onPrimaryContainer: AppColors.text,
    secondary: AppColors.text,
    onSecondary: AppColors.panel,
    secondaryContainer: AppColors.subtle,
    onSecondaryContainer: AppColors.text,
    surfaceTint: Colors.transparent,
  );
  return base.copyWith(
    colorScheme: scheme,
    progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.text),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.text,
      inactiveTrackColor: AppColors.line,
      thumbColor: AppColors.text,
      overlayColor: AppColors.text.withValues(alpha: 0.08),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.text),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: Colors.transparent,
        disabledForegroundColor: AppColors.faint,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: AppColors.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.line),
      ),
    ),
  );
}

class _CompanionHeader extends StatelessWidget {
  const _CompanionHeader({required this.phase, required this.onClose});

  final NoteCompanionPhase phase;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final status = switch (phase) {
      NoteCompanionPhase.connecting => 'Connecting…',
      NoteCompanionPhase.recording => 'Listening…',
      NoteCompanionPhase.waiting => 'Thinking…',
      NoteCompanionPhase.responding => 'Answering…',
      NoteCompanionPhase.error => 'Needs attention',
      NoteCompanionPhase.idle => 'Ask about this note',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 8, 5),
      child: Row(
        children: <Widget>[
          Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Minimize',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({
    required this.messages,
    required this.hasOlderMessages,
    required this.loadingOlder,
    required this.onLoadOlder,
  });

  final List<NoteCompanionMessage> messages;
  final bool hasOlderMessages;
  final bool loadingOlder;
  final VoidCallback onLoadOlder;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _loadRequested = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadOlder);
  }

  void _maybeLoadOlder() {
    if (_loadRequested || !widget.hasOlderMessages || widget.loadingOlder) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80) {
      _loadRequested = true;
      widget.onLoadOlder();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRequested = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_maybeLoadOlder)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount:
          widget.messages.length +
          (widget.hasOlderMessages || widget.loadingOlder ? 1 : 0),
      itemBuilder: (context, reverseIndex) {
        if (reverseIndex == widget.messages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: widget.loadingOlder
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Scroll up for earlier messages',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
            ),
          );
        }
        final message =
            widget.messages[widget.messages.length - reverseIndex - 1];
        return Align(
          alignment: message.fromUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 330),
            decoration: BoxDecoration(
              color: message.fromUser ? AppColors.accentSoft : AppColors.subtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: NoteCompanionMessageContent(
              text: message.text,
              fromUser: message.fromUser,
            ),
          ),
        );
      },
    );
  }
}

class NoteCompanionMessageContent extends StatelessWidget {
  const NoteCompanionMessageContent({
    required this.text,
    required this.fromUser,
    super.key,
  });

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = TextStyle(
      color: AppColors.text,
      fontSize: 13,
      height: 1.4,
    );
    if (fromUser) {
      return Text(text, style: bodyStyle);
    }
    return MarkdownBody(
      data: text,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: bodyStyle,
        a: bodyStyle.copyWith(
          color: AppColors.blue,
          decoration: TextDecoration.underline,
        ),
        strong: bodyStyle.copyWith(fontWeight: FontWeight.w700),
        em: bodyStyle.copyWith(fontStyle: FontStyle.italic),
        h1: bodyStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        h2: bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        h3: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        listBullet: bodyStyle,
        blockquote: bodyStyle.copyWith(color: AppColors.muted),
        code: bodyStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: AppColors.panel,
        ),
        blockSpacing: 8,
        listIndent: 18,
        tableBody: bodyStyle.copyWith(fontSize: 12),
        tableHead: bodyStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        tableBorder: TableBorder.all(color: AppColors.line),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        tableColumnWidth: const IntrinsicColumnWidth(),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.textController,
    required this.focusNode,
    required this.onSubmit,
    this.voiceEnabled = true,
  });

  final NoteCompanionController controller;
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final bool voiceEnabled;

  @override
  Widget build(BuildContext context) {
    final disabled = controller.isBusy;
    final showStop = controller.isRecording || controller.anyAudioPlaying;
    final micDisabled = disabled && !controller.anyAudioPlaying;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: textController,
              focusNode: focusNode,
              style: const TextStyle(fontSize: 13),
              enabled: !disabled && !controller.isRecording,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: 'Ask about this note...',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.faint),
                isDense: true,
              ),
            ),
          ),
          if (voiceEnabled) ...<Widget>[
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: showStop
                  ? controller.isRecording
                        ? 'Stop and ask'
                        : 'Stop playback'
                  : 'Ask by voice',
              onPressed: micDisabled
                  ? null
                  : showStop
                  ? () => unawaited(
                      controller.isRecording
                          ? controller.stopRecording()
                          : controller.stopPlayback(),
                    )
                  : () => unawaited(controller.startRecording()),
              icon: Icon(
                showStop ? Icons.stop_rounded : Icons.mic_none_rounded,
                size: 20,
              ),
            ),
          ],
          IconButton(
            tooltip: 'Send',
            onPressed: disabled || controller.isRecording ? null : onSubmit,
            icon: const Icon(Icons.arrow_upward_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

String? _scrollAnchorBlockKey(Map<String, dynamic> jsonDocument) {
  final viewState = jsonDocument['view_state'];
  if (viewState is! Map) return null;
  final anchor = viewState['scroll_anchor'];
  if (anchor is! Map) return null;
  final key = anchor['blockKey'];
  return key is String && key.isNotEmpty ? key : null;
}

String _formatDuration(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

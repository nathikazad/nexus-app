part of 'note_companion.dart';

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
    required this.onStartLiveConversation,
    this.voiceEnabled = true,
  });

  final NoteCompanionController controller;
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onStartLiveConversation;
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
          NoteCompanionComposerAction(
            textController: textController,
            disabled: disabled || controller.isRecording,
            onSend: onSubmit,
            onStartLiveConversation: onStartLiveConversation,
          ),
        ],
      ),
    );
  }
}

class NoteCompanionComposerAction extends StatelessWidget {
  const NoteCompanionComposerAction({
    required this.textController,
    required this.disabled,
    required this.onSend,
    required this.onStartLiveConversation,
    super.key,
  });

  final TextEditingController textController;
  final bool disabled;
  final VoidCallback onSend;
  final VoidCallback onStartLiveConversation;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: textController,
        builder: (context, value, _) {
          final hasText = value.text.trim().isNotEmpty;
          return IconButton(
            key: ValueKey<String>(
              hasText ? 'note-ai-send-button' : 'note-ai-live-button',
            ),
            tooltip: hasText ? 'Send' : 'Talk to AI',
            onPressed: disabled
                ? null
                : hasText
                ? onSend
                : onStartLiveConversation,
            icon: Icon(
              hasText
                  ? Icons.arrow_upward_rounded
                  : Icons.record_voice_over_outlined,
              size: 20,
            ),
          );
        },
      );
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

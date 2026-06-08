import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/transcript.dart';

class CurrentTranscriptChatTheme {
  const CurrentTranscriptChatTheme({
    required this.accent,
    required this.background,
    required this.surface,
    required this.inputBackground,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  final Color accent;
  final Color background;
  final Color surface;
  final Color inputBackground;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
}

class CurrentTranscriptChatPage extends ConsumerWidget {
  const CurrentTranscriptChatPage({
    super.key,
    required this.title,
    required this.theme,
    this.messageLimit = 30,
    this.liveMessages = const [],
    this.onSend,
  });

  final String title;
  final CurrentTranscriptChatTheme theme;
  final int messageLimit;
  final List<CurrentTranscriptChatMessage> liveMessages;
  final FutureOr<void> Function(String text)? onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcript = ref.watch(currentTranscriptProvider);

    return Scaffold(
      backgroundColor: theme.surface,
      body: SizedBox.expand(
        child: ColoredBox(
          color: theme.surface,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                        color: theme.textSecondary,
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(currentTranscriptProvider),
                        child: Text(
                          'refresh',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.border),
                Expanded(
                  child: Container(
                    color: theme.background,
                    child: transcript.when(
                      data: (value) => _TranscriptMessages(
                        transcript: value,
                        messageLimit: messageLimit,
                        liveMessages: liveMessages,
                        theme: theme,
                      ),
                      loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (error, _) => _TranscriptStatus(
                        message: 'Could not load transcript',
                        detail: error.toString(),
                        onRetry: () =>
                            ref.invalidate(currentTranscriptProvider),
                        theme: theme,
                      ),
                    ),
                  ),
                ),
                _Composer(theme: theme, onSend: onSend),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CurrentTranscriptChatMessage {
  const CurrentTranscriptChatMessage({
    required this.text,
    required this.fromUser,
    this.key,
    this.links = const [],
  });

  final String text;
  final bool fromUser;
  final String? key;
  final List<CurrentTranscriptChatLink> links;

  CurrentTranscriptChatMessage copyWith({
    String? text,
    bool? fromUser,
    String? key,
    List<CurrentTranscriptChatLink>? links,
  }) {
    return CurrentTranscriptChatMessage(
      text: text ?? this.text,
      fromUser: fromUser ?? this.fromUser,
      key: key ?? this.key,
      links: links ?? this.links,
    );
  }
}

class CurrentTranscriptChatLink {
  const CurrentTranscriptChatLink({
    required this.label,
    required this.url,
    this.kind = 'app_route',
    this.routeName,
  });

  final String label;
  final String url;
  final String kind;
  final String? routeName;
}

class _TranscriptMessages extends StatelessWidget {
  const _TranscriptMessages({
    required this.transcript,
    required this.messageLimit,
    required this.liveMessages,
    required this.theme,
  });

  final Transcript? transcript;
  final int messageLimit;
  final List<CurrentTranscriptChatMessage> liveMessages;
  final CurrentTranscriptChatTheme theme;

  @override
  Widget build(BuildContext context) {
    final allMessages =
        transcript?.sortedMessages ?? const <TranscriptMessage>[];
    final start = allMessages.length > messageLimit
        ? allMessages.length - messageLimit
        : 0;
    final transcriptMessages = allMessages.sublist(start);
    final messages = <CurrentTranscriptChatMessage>[
      for (final message in transcriptMessages)
        CurrentTranscriptChatMessage(
          key: 'transcript:${message.timestamp}',
          text: message.message,
          fromUser: message.isFromUser,
        ),
    ];
    for (final message in liveMessages) {
      final liveKey = _messageDedupeKey(message.fromUser, message.text);
      final duplicateIndex = messages.indexWhere(
        (candidate) =>
            _messageDedupeKey(candidate.fromUser, candidate.text) == liveKey,
      );
      if (duplicateIndex < 0) {
        messages.add(message);
      } else if (message.links.isNotEmpty) {
        messages[duplicateIndex] = messages[duplicateIndex].copyWith(
          links: message.links,
        );
      }
    }

    if (messages.isEmpty) {
      return _TranscriptStatus(
        message: 'No transcript messages yet',
        theme: theme,
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        final bubble = _TranscriptBubble(
          text: message.text,
          fromUser: message.fromUser,
          links: message.links,
          theme: theme,
        );
        return Padding(
          padding: EdgeInsets.only(top: index == messages.length - 1 ? 0 : 16),
          child: bubble,
        );
      },
    );
  }

  String _messageDedupeKey(bool fromUser, String text) {
    return '${fromUser ? 'user' : 'assistant'}:${text.trim()}';
  }
}

class _TranscriptStatus extends StatelessWidget {
  const _TranscriptStatus({
    required this.message,
    required this.theme,
    this.detail,
    this.onRetry,
  });

  final String message;
  final CurrentTranscriptChatTheme theme;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: theme.textMuted,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({
    required this.text,
    required this.fromUser,
    required this.links,
    required this.theme,
  });

  final String text;
  final bool fromUser;
  final List<CurrentTranscriptChatLink> links;
  final CurrentTranscriptChatTheme theme;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? theme.accent : theme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromUser ? 16 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 16),
          ),
          border: fromUser ? null : Border.all(color: theme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: fromUser ? 0.10 : 0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: fromUser ? Colors.white : theme.textPrimary,
              ),
            ),
            if (!fromUser && links.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final link in links)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _TranscriptLinkButton(link: link, theme: theme),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TranscriptLinkButton extends StatelessWidget {
  const _TranscriptLinkButton({required this.link, required this.theme});

  final CurrentTranscriptChatLink link;
  final CurrentTranscriptChatTheme theme;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.push(link.url),
      style: TextButton.styleFrom(
        foregroundColor: theme.accent,
        backgroundColor: theme.inputBackground,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: theme.accent),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: const Icon(Icons.open_in_new_rounded, size: 16),
      label: Text(
        link.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.theme, required this.onSend});

  final CurrentTranscriptChatTheme theme;
  final FutureOr<void> Function(String text)? onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final onSend = widget.onSend;
    if (text.isEmpty || onSend == null || _sending) return;

    setState(() => _sending = true);
    try {
      await onSend(text);
      _controller.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final canSend = widget.onSend != null && !_sending;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 12, right: 4),
              decoration: BoxDecoration(
                color: theme.inputBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: widget.onSend != null,
                      decoration: InputDecoration(
                        hintText: 'Ask anything...',
                        hintStyle: TextStyle(
                          color: theme.textMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(fontSize: 14, color: theme.textPrimary),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.mic_none_rounded, size: 20),
                    color: theme.textSecondary,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 4, top: 4),
                    child: Material(
                      color: theme.accent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: canSend ? _send : null,
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

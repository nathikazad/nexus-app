import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nx_live_agent/nx_live_agent.dart';
import 'package:nx_docs/core/theme/app_theme.dart';
import 'package:nx_docs/features/live_conversation/live_conversation_platform_policy.dart';
import 'package:nx_docs/features/live_conversation/note_live_conversation_coordinator.dart';
import 'package:nx_docs/features/live_conversation/note_live_conversation_controller.dart';
import 'package:nx_docs/features/live_conversation/widgets/live_conversation_floating_controls.dart';

class NoteLiveConversationPanel extends StatefulWidget {
  const NoteLiveConversationPanel({
    required this.coordinator,
    required this.onEnd,
    super.key,
  });

  final NoteLiveConversationCoordinator coordinator;
  final VoidCallback onEnd;

  @override
  State<NoteLiveConversationPanel> createState() =>
      _NoteLiveConversationPanelState();
}

class _NoteLiveConversationPanelState extends State<NoteLiveConversationPanel> {
  Future<void> _end() async {
    await widget.coordinator.stop();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.coordinator,
    builder: (context, _) {
      final controller = widget.coordinator.controller;
      if (controller == null) return const SizedBox.shrink();
      final sourceTitle = widget.coordinator.sourceDocument?.title;
      final controlLayout = LiveConversationPlatformPolicy.controlsFor(
        defaultTargetPlatform,
      );
      return Padding(
        key: const ValueKey<String>('note-live-conversation-panel'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sourceTitle == null
                        ? 'Live conversation'
                        : 'Live · $sourceTitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _phaseLabel(controller.phase),
                  style: TextStyle(
                    color: AppColors.faint,
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!widget.coordinator.hasRecap &&
                    controlLayout ==
                        LiveConversationControlLayout.macDesktop) ...[
                  const SizedBox(width: 8),
                  _VadToggle(controller: controller),
                ],
              ],
            ),
            const Divider(height: 24),
            if (widget.coordinator.hasRecap)
              Expanded(
                child: _LiveConversationRecap(
                  controller: controller,
                  onReturnToChat: widget.onEnd,
                ),
              )
            else ...[
              Expanded(
                child: controlLayout == LiveConversationControlLayout.macDesktop
                    ? _DesktopLiveConversation(controller: controller)
                    : Center(child: _LiveState(controller: controller)),
              ),
              const SizedBox(height: 12),
              LiveConversationFloatingControls(
                controller: controller,
                layout: controlLayout,
                stopping: widget.coordinator.isStopping,
                onStop: _end,
                heroPrefix:
                    'note-live-panel-${widget.coordinator.sourceDocument?.id ?? 0}',
              ),
              const SizedBox(height: 14),
              Text(
                'Temporary conversation · latest four exchanges retained',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.faint, fontSize: 11),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _VadToggle extends StatelessWidget {
  const _VadToggle({required this.controller});

  final NoteLiveConversationController controller;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.automaticVad;
    return Tooltip(
      message: enabled ? 'Turn off automatic VAD' : 'Turn on automatic VAD',
      child: InkWell(
        key: const ValueKey<String>('desktop-live-vad-toggle'),
        borderRadius: BorderRadius.circular(6),
        onTap:
            controller.phase == LiveAgentPhase.error ||
                controller.changingInputMode
            ? null
            : () => controller.toggleTurnDetection(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: enabled ? AppColors.accentSoft : Colors.transparent,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            enabled ? 'VAD ON' : 'VAD OFF',
            style: TextStyle(
              color: enabled ? AppColors.text : AppColors.faint,
              fontSize: 9,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveConversationRecap extends StatelessWidget {
  const _LiveConversationRecap({
    required this.controller,
    required this.onReturnToChat,
  });

  final NoteLiveConversationController controller;
  final VoidCallback onReturnToChat;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        const SizedBox(height: 18),
        Icon(
          Icons.check_circle_outline_rounded,
          color: AppColors.text,
          size: 46,
        ),
        const SizedBox(height: 12),
        const Text(
          'Conversation ended',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.subtle,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'GPT-REALTIME-2.1 MINI USAGE',
                style: TextStyle(
                  color: AppColors.faint,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _UsageRow(
                label: 'New input',
                tokens: controller.newInputTokens,
                cost: controller.newInputCost,
              ),
              const SizedBox(height: 8),
              _UsageRow(
                label: 'Cached input',
                tokens: controller.cachedInputTokens,
                cost: controller.cachedInputCost,
              ),
              const SizedBox(height: 8),
              _UsageRow(
                label: 'Output',
                tokens: controller.usage.billedOutputTokens,
                cost: controller.outputCost,
              ),
              const Divider(height: 22),
              _UsageRow(
                label: 'Total',
                tokens: controller.usage.totalTokens,
                cost: controller.totalCost,
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const ValueKey<String>('note-live-return-to-chat-button'),
          onPressed: onReturnToChat,
          child: const Text('Return to chat'),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.tokens,
    required this.cost,
    this.emphasized = false,
  });

  final String label;
  final int tokens;
  final double cost;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: emphasized ? AppColors.text : AppColors.muted,
      fontSize: 12,
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('$tokens tokens', style: style),
        const SizedBox(width: 12),
        SizedBox(
          width: 68,
          child: Text(
            _formatCost(cost),
            textAlign: TextAlign.right,
            style: style,
          ),
        ),
      ],
    );
  }
}

String _formatCost(double cost) {
  if (cost > 0 && cost < 0.0001) return '<\$0.0001';
  return '\$${cost.toStringAsFixed(4)}';
}

class _LiveState extends StatelessWidget {
  const _LiveState({required this.controller});

  final NoteLiveConversationController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.phase == LiveAgentPhase.error) {
      return Column(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.red, size: 52),
          const SizedBox(height: 18),
          const Text(
            'Live conversation could not start',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            controller.error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      );
    }
    return Column(
      children: [
        _StatusOrb(phase: controller.phase),
        const SizedBox(height: 22),
        Text(
          _phaseLabel(controller.phase),
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Talk naturally about this document.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DesktopLiveConversation extends StatelessWidget {
  const _DesktopLiveConversation({required this.controller});

  final NoteLiveConversationController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.phase == LiveAgentPhase.error) {
      return Center(child: _LiveState(controller: controller));
    }
    return Column(
      children: [
        _StatusOrb(phase: controller.phase),
        const SizedBox(height: 10),
        Text(
          _phaseLabel(controller.phase),
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _DesktopTranscript(messages: controller.transcriptMessages),
        ),
      ],
    );
  }
}

class _DesktopTranscript extends StatefulWidget {
  const _DesktopTranscript({required this.messages});

  final List<LiveAgentTranscriptMessage> messages;

  @override
  State<_DesktopTranscript> createState() => _DesktopTranscriptState();
}

class _DesktopTranscriptState extends State<_DesktopTranscript> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _DesktopTranscript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_transcriptSignature(oldWidget.messages) ==
        _transcriptSignature(widget.messages)) {
      return;
    }
    final followLatest =
        !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent -
                _scrollController.position.pixels <
            48;
    if (followLatest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('desktop-live-transcript'),
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.panel,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: SelectionArea(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: widget.messages.length > 2,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(10),
          child: widget.messages.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 18,
                  ),
                  child: Text(
                    'Your conversation will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.faint,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var index = 0;
                      index < widget.messages.length;
                      index += 1
                    ) ...[
                      _TranscriptMessage(message: widget.messages[index]),
                      if (index != widget.messages.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ),
    ),
  );
}

class _TranscriptMessage extends StatelessWidget {
  const _TranscriptMessage({required this.message});

  final LiveAgentTranscriptMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == LiveAgentTranscriptRole.user;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? AppColors.subtle : AppColors.bg,
        border: Border.all(color: isUser ? AppColors.subtle : AppColors.line),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUser ? 'YOU' : 'AGENT',
            style: TextStyle(
              color: AppColors.faint,
              fontSize: 9,
              height: 1,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message.text,
            style: TextStyle(
              color: AppColors.editorText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

String _transcriptSignature(List<LiveAgentTranscriptMessage> messages) =>
    messages
        .map((message) => '${message.role.index}:${message.text}')
        .join('|');

class _StatusOrb extends StatelessWidget {
  const _StatusOrb({required this.phase});

  final LiveAgentPhase phase;

  @override
  Widget build(BuildContext context) {
    final active =
        phase == LiveAgentPhase.speaking || phase == LiveAgentPhase.thinking;
    final size = phase == LiveAgentPhase.speaking ? 112.0 : 94.0;
    return SizedBox.square(
      dimension: 120,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.text : AppColors.subtle,
            border: Border.all(color: active ? AppColors.text : AppColors.line),
          ),
          child: Icon(
            phase == LiveAgentPhase.speaking
                ? Icons.graphic_eq_rounded
                : Icons.mic_none_rounded,
            color: active ? AppColors.bg : AppColors.text,
            size: 34,
          ),
        ),
      ),
    );
  }
}

String _phaseLabel(LiveAgentPhase phase) => switch (phase) {
  LiveAgentPhase.idle => 'READY',
  LiveAgentPhase.connecting => 'CONNECTING',
  LiveAgentPhase.listening => 'LISTENING',
  LiveAgentPhase.thinking => 'THINKING',
  LiveAgentPhase.speaking => 'SPEAKING',
  LiveAgentPhase.paused => 'PAUSED',
  LiveAgentPhase.closed => 'ENDED',
  LiveAgentPhase.error => 'ERROR',
};

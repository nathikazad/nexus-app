import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_voice_assistant/core/theme/app_theme.dart';
import 'package:nexus_voice_assistant/features/voice/voice_socket_controller.dart';

class VoiceListeningOverlay extends ConsumerWidget {
  const VoiceListeningOverlay({super.key});

  static const double _navReserve = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceSocketControllerProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: _navReserve + bottom,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref
                .read(voiceSocketControllerProvider.notifier)
                .dismissOverlay(),
            child: Container(color: const Color(0x660F172A)),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: _navReserve + bottom + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VoiceMessages(messages: voiceState.messages),
              if (voiceState.active || voiceState.error != null) ...[
                const SizedBox(height: 24),
                Center(
                  child: _ListeningPill(
                    phase: voiceState.phase,
                    error: voiceState.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VoiceMessages extends StatelessWidget {
  const _VoiceMessages({required this.messages});

  final List<VoiceOverlayMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();
    final visible =
        messages.length <= 4 ? messages : messages.sublist(messages.length - 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _VoiceBubble(message: visible[i]),
          if (i != visible.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({required this.message});

  final VoiceOverlayMessage message;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? AppColors.orange600 : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromUser ? 16 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: fromUser ? 0.15 : 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: fromUser ? Colors.white : AppColors.gray900,
          ),
        ),
      ),
    );
  }
}

class _ListeningPill extends StatefulWidget {
  const _ListeningPill({required this.phase, this.error});

  final VoiceSocketPhase phase;
  final String? error;

  @override
  State<_ListeningPill> createState() => _ListeningPillState();
}

class _ListeningPillState extends State<_ListeningPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _label {
    if (widget.error != null) return widget.error!;
    return switch (widget.phase) {
      VoiceSocketPhase.connecting => 'Connecting...',
      VoiceSocketPhase.recording => 'Listening...',
      VoiceSocketPhase.waiting => 'Thinking...',
      VoiceSocketPhase.responding => 'Responding...',
      VoiceSocketPhase.error => 'Voice unavailable',
      VoiceSocketPhase.idle => 'Done',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isError =
        widget.error != null || widget.phase == VoiceSocketPhase.error;
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isError ? AppColors.gray400 : AppColors.red600,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.62,
              ),
              child: Text(
                _label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray600,
                ),
              ),
            ),
            if (!isError) ...[
              const SizedBox(width: 10),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(4, (i) {
                      final t = (_controller.value + i * 0.15) % 1.0;
                      final h =
                          6.0 + 8 * (0.5 + 0.5 * (t < 0.5 ? t * 2 : 2 - t * 2));
                      return Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Container(
                          width: 2,
                          height: h,
                          decoration: BoxDecoration(
                            color: AppColors.gray200,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

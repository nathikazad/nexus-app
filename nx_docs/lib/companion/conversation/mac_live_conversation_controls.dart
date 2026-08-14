import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nx_live_agent/nx_live_agent.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/companion/conversation/conversation_controller.dart';

class MacLiveConversationControls extends StatelessWidget {
  const MacLiveConversationControls({
    required this.controller,
    required this.stopping,
    required this.onStop,
    required this.heroPrefix,
    super.key,
  });

  final NoteLiveConversationController controller;
  final bool stopping;
  final Future<void> Function() onStop;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final manual = !controller.automaticVad;
    final assistantActive =
        controller.phase == LiveAgentPhase.speaking ||
        controller.playbackPaused;
    final waitingForAssistant =
        controller.phase == LiveAgentPhase.connecting ||
        controller.phase == LiveAgentPhase.thinking ||
        controller.manualSubmitting;
    return Row(
      key: const ValueKey<String>('mac-live-conversation-controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (manual) ...[
          _LiveFab(
            heroTag: '$heroPrefix-microphone',
            tooltip: controller.manualRecording
                ? 'Send recording'
                : assistantActive
                ? 'Interrupt and start recording'
                : 'Start recording',
            onPressed:
                controller.phase == LiveAgentPhase.error ||
                    controller.changingInputMode ||
                    waitingForAssistant
                ? null
                : () => unawaited(controller.activateMicrophone()),
            icon: controller.manualRecording
                ? Icons.fiber_manual_record_rounded
                : Icons.mic_rounded,
            progress: controller.manualSubmitting,
            backgroundColor: controller.manualRecording ? AppColors.red : null,
          ),
          if (assistantActive) ...[
            const SizedBox(width: 8),
            _LiveFab(
              heroTag: '$heroPrefix-playback',
              tooltip: controller.playbackPaused
                  ? 'Resume live playback'
                  : 'Pause live playback',
              onPressed: controller.phase == LiveAgentPhase.error
                  ? null
                  : () => unawaited(controller.togglePlayback()),
              icon: controller.playbackPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
            ),
          ],
          const SizedBox(width: 8),
        ],
        _LiveFab(
          heroTag: '$heroPrefix-stop',
          tooltip: 'Stop live conversation',
          onPressed: stopping ? null : () => unawaited(onStop()),
          icon: Icons.stop_rounded,
          progress: stopping,
        ),
      ],
    );
  }
}

class _LiveFab extends StatelessWidget {
  const _LiveFab({
    required this.heroTag,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.progress = false,
    this.backgroundColor,
  });

  final String heroTag;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool progress;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: FloatingActionButton.small(
      heroTag: heroTag,
      elevation: 2,
      backgroundColor: backgroundColor ?? AppColors.floating,
      foregroundColor: AppColors.onFloating,
      onPressed: onPressed,
      child: progress
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
    ),
  );
}

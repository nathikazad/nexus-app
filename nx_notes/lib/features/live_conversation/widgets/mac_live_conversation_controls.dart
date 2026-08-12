import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nx_live_agent/nx_live_agent.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/features/live_conversation/note_live_conversation_controller.dart';

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
  Widget build(BuildContext context) => Row(
    key: const ValueKey<String>('mac-live-conversation-controls'),
    mainAxisSize: MainAxisSize.min,
    children: [
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
      const SizedBox(width: 8),
      _LiveFab(
        heroTag: '$heroPrefix-microphone',
        tooltip: _microphoneTooltip(controller),
        onPressed:
            controller.phase == LiveAgentPhase.error ||
                controller.playbackPaused ||
                controller.changingInputMode
            ? null
            : () => unawaited(controller.activateMicrophone()),
        icon: _microphoneIcon(controller),
        progress: controller.manualSubmitting,
      ),
      const SizedBox(width: 8),
      _LiveFab(
        heroTag: '$heroPrefix-stop',
        tooltip: 'Stop live conversation',
        onPressed: stopping ? null : () => unawaited(onStop()),
        icon: Icons.stop_rounded,
        progress: stopping,
      ),
      const SizedBox(width: 8),
      _LiveFab(
        heroTag: '$heroPrefix-turn',
        tooltip: controller.automaticVad
            ? 'Turn off automatic VAD'
            : 'Turn on automatic VAD',
        onPressed:
            controller.phase != LiveAgentPhase.error &&
                !controller.changingInputMode
            ? () => unawaited(controller.toggleTurnDetection())
            : null,
        icon: controller.automaticVad
            ? Icons.front_hand_rounded
            : Icons.do_not_touch_rounded,
        progress: controller.changingInputMode,
      ),
    ],
  );
}

String _microphoneTooltip(NoteLiveConversationController controller) {
  if (controller.automaticVad) {
    return controller.muted ? 'Unmute microphone' : 'Mute microphone';
  }
  return controller.manualRecording ? 'Send recording' : 'Start recording';
}

IconData _microphoneIcon(NoteLiveConversationController controller) {
  if (controller.automaticVad) {
    return controller.muted ? Icons.mic_off_rounded : Icons.mic_rounded;
  }
  return controller.manualRecording ? Icons.send_rounded : Icons.mic_rounded;
}

class _LiveFab extends StatelessWidget {
  const _LiveFab({
    required this.heroTag,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.progress = false,
  });

  final String heroTag;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool progress;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: FloatingActionButton.small(
      heroTag: heroTag,
      elevation: 2,
      backgroundColor: AppColors.floating,
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nx_docs/core/theme/app_theme.dart';
import 'package:nx_docs/features/live_conversation/note_live_conversation_controller.dart';

class IosLiveConversationControls extends StatelessWidget {
  const IosLiveConversationControls({
    required this.controller,
    required this.stopping,
    required this.onStop,
    super.key,
  });

  final NoteLiveConversationController controller;
  final bool stopping;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey<String>('ios-live-conversation-bottom-bar'),
    color: AppColors.floating,
    elevation: 3,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey<String>('ios-live-mute-button'),
          tooltip: controller.automaticVad
              ? (controller.muted ? 'Unmute microphone' : 'Mute microphone')
              : (controller.manualRecording
                    ? 'Send recording'
                    : 'Start recording'),
          onPressed: () => unawaited(controller.activateMicrophone()),
          color: AppColors.onFloating,
          icon: Icon(
            controller.automaticVad && controller.muted
                ? Icons.mic_off_rounded
                : controller.manualRecording
                ? Icons.send_rounded
                : Icons.mic_rounded,
          ),
        ),
        Container(width: 1, height: 24, color: AppColors.line),
        IconButton(
          key: const ValueKey<String>('ios-live-stop-button'),
          tooltip: 'Stop live conversation',
          onPressed: stopping ? null : () => unawaited(onStop()),
          color: AppColors.onFloating,
          icon: stopping
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.stop_rounded),
        ),
      ],
    ),
  );
}

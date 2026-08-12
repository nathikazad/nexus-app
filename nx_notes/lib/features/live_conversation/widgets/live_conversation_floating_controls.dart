import 'package:flutter/material.dart';
import 'package:nx_notes/features/live_conversation/live_conversation_platform_policy.dart';
import 'package:nx_notes/features/live_conversation/note_live_conversation_controller.dart';
import 'package:nx_notes/features/live_conversation/widgets/ios_live_conversation_controls.dart';
import 'package:nx_notes/features/live_conversation/widgets/mac_live_conversation_controls.dart';

class LiveConversationFloatingControls extends StatelessWidget {
  const LiveConversationFloatingControls({
    required this.controller,
    required this.layout,
    required this.stopping,
    required this.onStop,
    required this.heroPrefix,
    super.key,
  });

  final NoteLiveConversationController controller;
  final LiveConversationControlLayout layout;
  final bool stopping;
  final Future<void> Function() onStop;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) => switch (layout) {
    LiveConversationControlLayout.macDesktop => MacLiveConversationControls(
      controller: controller,
      stopping: stopping,
      onStop: onStop,
      heroPrefix: heroPrefix,
    ),
    LiveConversationControlLayout.mobileBottomBar =>
      IosLiveConversationControls(
        controller: controller,
        stopping: stopping,
        onStop: onStop,
      ),
  };
}

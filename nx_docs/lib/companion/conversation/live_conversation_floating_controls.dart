import 'package:flutter/material.dart';
import 'package:nx_docs/companion/conversation/conversation_policy.dart';
import 'package:nx_docs/companion/conversation/conversation_controller.dart';
import 'package:nx_docs/companion/conversation/ios_live_conversation_controls.dart';
import 'package:nx_docs/companion/conversation/mac_live_conversation_controls.dart';

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

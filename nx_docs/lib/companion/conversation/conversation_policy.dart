import 'package:flutter/foundation.dart';

enum LiveConversationControlLayout { macDesktop, mobileBottomBar }

final class LiveConversationPlatformPolicy {
  const LiveConversationPlatformPolicy._();

  static LiveConversationControlLayout controlsFor(TargetPlatform platform) =>
      platform == TargetPlatform.macOS
      ? LiveConversationControlLayout.macDesktop
      : LiveConversationControlLayout.mobileBottomBar;

  static bool useBufferedRealtimeTransport({
    required bool isWeb,
    required TargetPlatform platform,
  }) => !isWeb && platform == TargetPlatform.macOS;
}

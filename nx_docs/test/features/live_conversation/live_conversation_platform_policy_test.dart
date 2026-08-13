import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/features/live_conversation/live_conversation_platform_policy.dart';

void main() {
  test('Mac gets buffered transport and desktop controls', () {
    expect(
      LiveConversationPlatformPolicy.controlsFor(TargetPlatform.macOS),
      LiveConversationControlLayout.macDesktop,
    );
    expect(
      LiveConversationPlatformPolicy.useBufferedRealtimeTransport(
        isWeb: false,
        platform: TargetPlatform.macOS,
      ),
      isTrue,
    );
  });

  test('iPhone keeps WebRTC and receives the compact control bar', () {
    expect(
      LiveConversationPlatformPolicy.controlsFor(TargetPlatform.iOS),
      LiveConversationControlLayout.mobileBottomBar,
    );
    expect(
      LiveConversationPlatformPolicy.useBufferedRealtimeTransport(
        isWeb: false,
        platform: TargetPlatform.iOS,
      ),
      isFalse,
    );
  });
}

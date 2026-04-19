import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/core/widgets/message_bubble.dart';

void main() {
  testWidgets('MessageBubble matches golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: MessageBubble(
              message: ChatMessage(
                text: 'Golden snapshot',
                isFromUser: false,
                timestamp: DateTime(2026, 4, 19, 12),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MessageBubble),
      matchesGoldenFile('goldens/message_bubble.png'),
    );
  });
}

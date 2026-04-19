import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/domain/ai/interaction.dart';

void main() {
  test('Interaction append helpers mutate strings', () {
    final i = Interaction(
      userQuery: 'a',
      aiResponse: 'b',
      timestamp: DateTime(2020),
    );
    i.addToUserQuery('b');
    i.addToAiResponse('c');
    expect(i.userQuery, 'ab');
    expect(i.aiResponse, 'bc');
  });
}

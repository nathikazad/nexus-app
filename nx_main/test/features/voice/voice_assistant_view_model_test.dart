import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/data/voice/voice_transcript_source.dart';
import 'package:nexus_voice_assistant/features/voice/voice_assistant_view_model.dart';
import 'package:nx_db/nx_db.dart' as nx;

import '../../_support/fake_voice_transcript_source.dart';

void main() {
  test('VoiceAssistantViewNotifier mirrors transcript provider', () async {
    final fake = FakeVoiceTranscriptSource()
      ..transcript = nx.Transcript(
        id: 3,
        messages: {},
      );

    final container = ProviderContainer(
      overrides: [
        voiceTranscriptSourceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(() {
      fake.dispose();
      container.dispose();
    });

    container.read(voiceAssistantViewModelProvider);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(voiceAssistantViewModelProvider).transcript.transcript?.id,
      3,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/data/voice/voice_transcript_notifier.dart';
import 'package:nexus_voice_assistant/data/voice/voice_transcript_source.dart';
import 'package:nx_db/nx_db.dart' as nx;

import '../../_support/fake_voice_transcript_source.dart';

void main() {
  test('loads transcript from injected source', () async {
    final fake = FakeVoiceTranscriptSource()
      ..transcript = nx.Transcript(
        id: 9,
        messages: {
          't1': nx.TranscriptMessage(
            timestamp: 't1',
            sender: 'Human',
            message: 'hello',
          ),
        },
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

    container.read(voiceTranscriptNotifierProvider);
    await Future<void>.delayed(Duration.zero);

    final s = container.read(voiceTranscriptNotifierProvider);
    expect(s.isLoading, isFalse);
    expect(s.error, isNull);
    expect(s.transcript?.id, 9);
    expect(s.transcript?.messages['t1']?.message, 'hello');
  });

  test('getTranscript error surfaces on state', () async {
    final fake = FakeVoiceTranscriptSource()
      ..getTranscriptError = StateError('network');

    final container = ProviderContainer(
      overrides: [
        voiceTranscriptSourceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(() {
      fake.dispose();
      container.dispose();
    });

    container.read(voiceTranscriptNotifierProvider);
    await Future<void>.delayed(Duration.zero);

    final s = container.read(voiceTranscriptNotifierProvider);
    expect(s.isLoading, isFalse);
    expect(s.transcript, isNull);
    expect(s.error, isA<StateError>());
  });

  test('stream message updates transcript', () async {
    final fake = FakeVoiceTranscriptSource()
      ..transcript = nx.Transcript(
        id: 42,
        messages: {
          'a': nx.TranscriptMessage(
            timestamp: 'a',
            sender: 'AI',
            message: 'first',
          ),
        },
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

    container.read(voiceTranscriptNotifierProvider);
    await Future<void>.delayed(Duration.zero);

    fake.controllerFor(42)?.add(
      nx.TranscriptMessage(
        timestamp: 'b',
        sender: 'Human',
        message: 'second',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final s = container.read(voiceTranscriptNotifierProvider);
    expect(s.transcript?.messages.containsKey('b'), isTrue);
    expect(s.transcript?.messages['b']?.message, 'second');
  });
}

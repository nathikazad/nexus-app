import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_voice_assistant/data/providers.dart';

class VoiceAssistantViewState {
  const VoiceAssistantViewState({required this.transcript});

  final VoiceTranscriptState transcript;
}

class VoiceAssistantViewNotifier extends Notifier<VoiceAssistantViewState> {
  @override
  VoiceAssistantViewState build() {
    final t = ref.watch(voiceTranscriptNotifierProvider);
    return VoiceAssistantViewState(transcript: t);
  }

  void refreshTranscript() {
    ref.read(voiceTranscriptNotifierProvider.notifier).refresh();
  }

  Future<void> sendTrimmedText(String raw) async {
    final text = raw.trim();
    final transcript = state.transcript.transcript;
    if (text.isEmpty || transcript == null) {
      return;
    }
    final bg = ref.read(bleBackgroundServiceProvider);
    bg.sendTextToSocket(text);
    bg.sendEofToSocket();
  }
}

final voiceAssistantViewModelProvider =
    NotifierProvider<VoiceAssistantViewNotifier, VoiceAssistantViewState>(
  VoiceAssistantViewNotifier.new,
);

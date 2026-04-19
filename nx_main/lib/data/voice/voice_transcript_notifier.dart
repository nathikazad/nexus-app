import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart' show TranscriptMessage;
import 'package:nexus_voice_assistant/data/voice/voice_transcript_mapping.dart';
import 'package:nexus_voice_assistant/data/voice/voice_transcript_source.dart';
import 'package:nexus_voice_assistant/domain/voice/voice_transcript.dart';

class VoiceTranscriptState {
  const VoiceTranscriptState({
    this.transcript,
    this.isLoading = false,
    this.error,
  });

  final VoiceTranscript? transcript;
  final bool isLoading;
  final Object? error;
}

class VoiceTranscriptNotifier extends Notifier<VoiceTranscriptState> {
  StreamSubscription<TranscriptMessage>? _messageSubscription;
  int? _currentTranscriptId;
  bool _loadScheduled = false;

  VoiceTranscriptSource get _source => ref.read(voiceTranscriptSourceProvider);

  @override
  VoiceTranscriptState build() {
    ref.onDispose(() {
      _messageSubscription?.cancel();
    });
    if (!_loadScheduled) {
      _loadScheduled = true;
      Future.microtask(_loadTranscript);
      return const VoiceTranscriptState(isLoading: true);
    }
    return state;
  }

  Future<void> refresh() => _loadTranscript();

  Future<void> _loadTranscript() async {
    state = VoiceTranscriptState(
      transcript: state.transcript,
      isLoading: true,
      error: null,
    );
    try {
      final t = await _source.getTranscript();
      final vt = mapTranscript(t);
      _messageSubscription?.cancel();
      _messageSubscription = null;
      _currentTranscriptId = t?.id;
      if (t != null) {
        _startMessageSubscription();
      }
      state = VoiceTranscriptState(transcript: vt, isLoading: false);
    } catch (e) {
      state = VoiceTranscriptState(isLoading: false, error: e);
    }
  }

  void _startMessageSubscription() {
    _messageSubscription?.cancel();
    final id = _currentTranscriptId;
    if (id == null) return;
    _messageSubscription = _source.streamMessages(id).listen(
      (message) {
        final cur = state.transcript;
        if (cur == null) return;
        state = VoiceTranscriptState(
          transcript: cur.copyWithMessage(mapTranscriptMessage(message)),
          isLoading: false,
        );
      },
      onError: (Object error) {},
    );
  }
}

final voiceTranscriptNotifierProvider =
    NotifierProvider<VoiceTranscriptNotifier, VoiceTranscriptState>(
  VoiceTranscriptNotifier.new,
);

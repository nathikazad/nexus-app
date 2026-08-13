import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nx_docs/data/ai/note_ai_session.dart';
import 'package:nx_docs/data/ai/note_transcript_service.dart';
import 'package:nx_docs/data/document/document_audio_service.dart';
import 'package:nx_docs/domain/document/document_audio.dart';
import 'package:nx_voice/nx_voice.dart';
import 'package:nx_voice/stored_audio.dart';

enum NoteCompanionPhase {
  idle,
  connecting,
  recording,
  waiting,
  responding,
  error,
}

class NoteCompanionMessage {
  const NoteCompanionMessage({
    required this.role,
    required this.text,
    this.turnkey,
    this.ephemeral = false,
  });

  final String role;
  final String text;
  final String? turnkey;
  final bool ephemeral;

  bool get fromUser => role == 'user';

  NoteCompanionMessage copyWith({
    String? text,
    String? turnkey,
    bool? ephemeral,
  }) {
    return NoteCompanionMessage(
      role: role,
      text: text ?? this.text,
      turnkey: turnkey ?? this.turnkey,
      ephemeral: ephemeral ?? this.ephemeral,
    );
  }
}

class NoteCompanionController extends ChangeNotifier {
  NoteCompanionController({
    required this.documentId,
    required this.socketUrl,
    required this.userId,
    required DocumentAudioService audioService,
    required NoteTranscriptLoader transcriptLoader,
    this.onAudioBlockChanged,
    DocumentAudio? initialAudio,
    String? initialBlockKey,
    NoteAiSession? session,
    NxMicrophoneOpusStreamer? microphone,
    NxWavAudioPlayer? player,
    NxStoredAudioPlayer? noteAudioPlayer,
  }) : _session = session ?? NoteAiSession(),
       _microphone = microphone ?? NxMicrophoneOpusStreamer(),
       _player = player ?? NxWavAudioPlayer(),
       _audioService = audioService,
       _transcriptLoader = transcriptLoader,
       _noteAudioPlayer = noteAudioPlayer ?? NxStoredAudioPlayer(),
       _audio = initialAudio,
       _initialBlockKey = initialBlockKey {
    _duration = initialAudio?.manifest.duration ?? Duration.zero;
    _player.onPlaybackStateChanged = (playing) {
      _assistantAudioPlaying = playing;
      _notify();
    };
    _noteAudioPlayer.onProgress = _handleNoteAudioProgress;
    _noteAudioPlayer.onPlaybackStateChanged = (playing) {
      _noteAudioPlaying = playing;
      _notify();
    };
    _noteAudioPlayer.onLoadingStateChanged = (loading) {
      _loadingNoteAudio = loading;
      _notify();
    };
    _noteAudioPlayer.onComplete = () {
      _noteAudioPlaying = false;
      _position = Duration.zero;
      _lastPlaybackBlockKey = null;
      _notify();
    };
  }

  final int documentId;
  final String socketUrl;
  final String userId;
  final NoteAiSession _session;
  final NxMicrophoneOpusStreamer _microphone;
  final NxWavAudioPlayer _player;
  final DocumentAudioService _audioService;
  final NoteTranscriptLoader _transcriptLoader;
  final NxStoredAudioPlayer _noteAudioPlayer;
  final ValueChanged<DocumentAudioBlockTiming>? onAudioBlockChanged;
  final String? _initialBlockKey;

  NoteCompanionPhase _phase = NoteCompanionPhase.idle;
  String? _error;
  final List<NoteCompanionMessage> _messages = <NoteCompanionMessage>[];
  bool _disposed = false;
  bool _stopInFlight = false;
  bool _generatingAudio = false;
  bool _noteAudioPlaying = false;
  bool _loadingNoteAudio = false;
  bool _assistantAudioPlaying = false;
  bool _suppressAssistantAudio = false;
  bool _historyLoaded = false;
  bool _loadingHistory = false;
  final List<NoteCompanionMessage> _olderMessages = <NoteCompanionMessage>[];
  DocumentAudio? _audio;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _noteAudioPlaybackSpeed = 1;
  String? _lastPlaybackBlockKey;

  NoteCompanionPhase get phase => _phase;
  String? get error => _error;
  List<NoteCompanionMessage> get messages => List.unmodifiable(_messages);
  bool get isRecording => _phase == NoteCompanionPhase.recording;
  bool get generatingAudio => _generatingAudio;
  bool get hasAudio => _audio != null;
  bool get noteAudioPlaying => _noteAudioPlaying;
  bool get loadingNoteAudio => _loadingNoteAudio;
  bool get assistantAudioPlaying => _assistantAudioPlaying;
  bool get anyAudioPlaying => _assistantAudioPlaying || _noteAudioPlaying;
  bool get loadingHistory => _loadingHistory;
  bool get hasOlderMessages => _olderMessages.isNotEmpty;
  Duration get audioPosition => _position;
  Duration get audioDuration => _duration;
  double get noteAudioPlaybackSpeed => _noteAudioPlaybackSpeed;
  bool get isBusy => switch (_phase) {
    NoteCompanionPhase.connecting ||
    NoteCompanionPhase.waiting ||
    NoteCompanionPhase.responding => true,
    _ => false,
  };

  Future<void> sendText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || isRecording || isBusy) return;
    _messages.add(NoteCompanionMessage(role: 'user', text: text));
    await pauseNoteAudio();
    _setPhase(NoteCompanionPhase.connecting, clearError: true);
    try {
      await _connect();
      _session.sendTextTurn(text);
      _setPhase(NoteCompanionPhase.waiting);
    } catch (error) {
      _setError(error);
    }
  }

  Future<void> startRecording() async {
    if (isRecording || isBusy) return;
    _setPhase(NoteCompanionPhase.connecting, clearError: true);
    try {
      await pauseNoteAudio();
      await _connect();
      await _player.stop();
      _session.beginAudioTurn();
      final started = await _microphone.start(
        onOpusPacket: _session.sendAudioPacket,
        onError: _setError,
      );
      if (!started) {
        _setError(StateError('Microphone permission is required.'));
        return;
      }
      _setPhase(NoteCompanionPhase.recording);
    } catch (error) {
      _setError(error);
    }
  }

  Future<void> stopRecording() async {
    if (!isRecording || _stopInFlight) return;
    _stopInFlight = true;
    _setPhase(NoteCompanionPhase.waiting);
    try {
      final remainder = await _microphone.stop();
      for (final packet in remainder) {
        _session.sendAudioPacket(packet);
      }
      _session.endAudioTurn();
    } catch (error) {
      _setError(error);
    } finally {
      _stopInFlight = false;
    }
  }

  Future<void> generateAudio({bool overwrite = false}) async {
    if (_generatingAudio) return;
    _generatingAudio = true;
    _error = null;
    _notify();
    try {
      final audio = await _audioService.generate(
        documentId: documentId,
        overwrite: overwrite,
      );
      await _noteAudioPlayer.stop();
      _audio = audio;
      _position = Duration.zero;
      _duration = audio.manifest.duration;
      _lastPlaybackBlockKey = null;
    } catch (error) {
      _setError(error);
    } finally {
      _generatingAudio = false;
      _notify();
    }
  }

  Future<void> toggleNoteAudio() async {
    final audio = _audio;
    if (audio == null || _generatingAudio || _loadingNoteAudio) return;
    try {
      if (_noteAudioPlaying) {
        await pauseNoteAudio();
        return;
      }
      final initialBlock = _position == Duration.zero
          ? audio.manifest.blockForKey(_initialBlockKey)
          : null;
      if (initialBlock != null) {
        _position = initialBlock.start;
      }
      await _noteAudioPlayer.play(
        audio.url,
        startAt: _position > Duration.zero ? _position : null,
        duration: audio.manifest.duration,
      );
    } catch (error) {
      _setError(error);
    }
  }

  Future<void> pauseNoteAudio() async {
    if (!_noteAudioPlaying) return;
    await _noteAudioPlayer.pause();
  }

  Future<void> stopPlayback() async {
    if (_assistantAudioPlaying) {
      _suppressAssistantAudio = true;
      await _player.stop();
    }
    if (_noteAudioPlaying) {
      await pauseNoteAudio();
    }
  }

  Future<void> loadHistory() async {
    if (_historyLoaded || _loadingHistory) return;
    _loadingHistory = true;
    _notify();
    try {
      final transcript = await _transcriptLoader.loadForDocument(documentId);
      final storedMessages = transcript?.sortedMessages;
      if (storedMessages != null) {
        final history = storedMessages
            .where((message) => message.message.trim().isNotEmpty)
            .where(
              (message) =>
                  message.sender.toLowerCase() == 'human' ||
                  message.sender.toLowerCase() == 'agent',
            )
            .map(
              (message) => NoteCompanionMessage(
                role: message.sender.toLowerCase() == 'human'
                    ? 'user'
                    : 'assistant',
                text: message.message,
                turnkey: 'history-${message.timestamp}',
              ),
            )
            .toList();
        final visibleStart = (history.length - 6).clamp(0, history.length);
        _olderMessages.addAll(history.take(visibleStart));
        _messages.insertAll(0, history.skip(visibleStart));
      }
      _historyLoaded = true;
    } catch (_) {
      // History is supplementary; a failed fetch must not block a new turn.
    } finally {
      _loadingHistory = false;
      _notify();
    }
  }

  void loadOlderMessages() {
    if (_olderMessages.isEmpty) return;
    final start = (_olderMessages.length - 10).clamp(0, _olderMessages.length);
    final page = _olderMessages.sublist(start);
    _olderMessages.removeRange(start, _olderMessages.length);
    _messages.insertAll(0, page);
    _notify();
  }

  Future<void> seekNoteAudio(Duration position) async {
    final bounded = Duration(
      milliseconds: position.inMilliseconds.clamp(0, _duration.inMilliseconds),
    );
    _position = bounded;
    await _noteAudioPlayer.seek(bounded);
    _syncBlockForPosition(bounded);
    _notify();
  }

  Future<void> setNoteAudioPlaybackSpeed(double speed) async {
    if (!speed.isFinite || speed <= 0) return;
    try {
      await _noteAudioPlayer.setSpeed(speed);
      _noteAudioPlaybackSpeed = speed;
      _notify();
    } catch (error) {
      _setError(error);
    }
  }

  void _handleNoteAudioProgress(Duration position, Duration duration) {
    _position = position;
    if (duration > Duration.zero) _duration = duration;
    _syncBlockForPosition(position);
    _notify();
  }

  void _syncBlockForPosition(Duration position) {
    final block = _audio?.manifest.blockAt(position);
    if (block == null || block.blockKey == _lastPlaybackBlockKey) return;
    _lastPlaybackBlockKey = block.blockKey;
    onAudioBlockChanged?.call(block);
  }

  void clearError() {
    _error = null;
    if (_phase == NoteCompanionPhase.error) {
      _phase = NoteCompanionPhase.idle;
    }
    _notify();
  }

  Future<void> _connect() async {
    _session.onAudioChunk = (packet) {
      if (_phase == NoteCompanionPhase.waiting) {
        _setPhase(NoteCompanionPhase.responding);
      }
      if (!_suppressAssistantAudio) {
        unawaited(_player.addOpusPacket(packet.opus));
      }
    };
    _session.onAudioEof = (_) {
      if (!_suppressAssistantAudio) {
        unawaited(_player.flush());
      }
      _suppressAssistantAudio = false;
      _setPhase(NoteCompanionPhase.idle);
    };
    _session.onTextChunk = (packet) {
      _handleTextPacket(
        packet.text,
        fallbackTurnkey: 'text-stream-${packet.streamIndex}',
      );
      if (_phase == NoteCompanionPhase.waiting) {
        _setPhase(NoteCompanionPhase.responding);
      }
    };
    _session.onTextEof = (_) => _setPhase(NoteCompanionPhase.idle);
    _session.onError = _setError;
    await _session.connect(
      NoteAiSessionConfig(
        socketUrl: socketUrl,
        userId: userId,
        documentId: documentId,
      ),
    );
  }

  void _handleTextPacket(String raw, {required String fallbackTurnkey}) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _appendAssistantDelta(raw, turnkey: fallbackTurnkey, ephemeral: false);
        return;
      }
      final type = decoded['type'];
      final role = decoded['role'];
      final text = decoded['text'];
      if ((type != 'transcript' && type != 'transcript-delta') ||
          role is! String ||
          text is! String ||
          text.trim().isEmpty) {
        return;
      }
      final turnkey = decoded['turnkey'] is String
          ? decoded['turnkey'] as String
          : role == 'assistant'
          ? fallbackTurnkey
          : null;
      if (type == 'transcript-delta') {
        if (role == 'assistant') {
          _appendAssistantDelta(
            text,
            turnkey: turnkey,
            ephemeral: decoded['ephemeral'] == true,
          );
        } else {
          _upsertMessage(role: role, text: text, turnkey: turnkey);
        }
      } else {
        _upsertMessage(role: role, text: text, turnkey: turnkey);
      }
    } catch (_) {
      if (raw.trim().isNotEmpty) {
        _appendAssistantDelta(raw, turnkey: fallbackTurnkey, ephemeral: false);
      }
    }
  }

  void _upsertMessage({
    required String role,
    required String text,
    required String? turnkey,
  }) {
    final index = _findMessage(role: role, turnkey: turnkey);
    if (index >= 0) {
      _messages[index] = _messages[index].copyWith(
        text: text,
        turnkey: turnkey,
        ephemeral: false,
      );
    } else {
      _messages.add(
        NoteCompanionMessage(role: role, text: text, turnkey: turnkey),
      );
    }
    _notify();
  }

  void _appendAssistantDelta(
    String text, {
    required String? turnkey,
    required bool ephemeral,
  }) {
    final index = _findMessage(role: 'assistant', turnkey: turnkey);
    if (index >= 0) {
      final existing = _messages[index];
      _messages[index] = existing.copyWith(
        text: ephemeral || existing.ephemeral ? text : existing.text + text,
        turnkey: turnkey,
        ephemeral: ephemeral,
      );
    } else {
      _messages.add(
        NoteCompanionMessage(
          role: 'assistant',
          text: text,
          turnkey: turnkey,
          ephemeral: ephemeral,
        ),
      );
    }
    _notify();
  }

  int _findMessage({required String role, required String? turnkey}) {
    for (var index = _messages.length - 1; index >= 0; index--) {
      final message = _messages[index];
      if (message.role != role) continue;
      if (message.turnkey == turnkey) {
        return index;
      }
    }
    return -1;
  }

  void _setPhase(NoteCompanionPhase value, {bool clearError = false}) {
    _phase = value;
    if (clearError) _error = null;
    _notify();
  }

  void _setError(Object error) {
    debugPrint('[nx_docs companion] error=$error');
    _error = error.toString().replaceFirst('Bad state: ', '');
    _phase = NoteCompanionPhase.error;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_microphone.dispose());
    unawaited(_player.dispose());
    unawaited(_noteAudioPlayer.dispose());
    unawaited(_session.disconnect());
    _audioService.dispose();
    super.dispose();
  }
}

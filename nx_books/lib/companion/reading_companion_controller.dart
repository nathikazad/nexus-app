import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nx_voice/nx_voice.dart';

class ReadingMessage {
  const ReadingMessage(this.role, this.text, {this.turn});
  final String role;
  final String text;
  final String? turn;
}

/// One document conversation, shared by typed and recorded turns.
class ReadingCompanionController extends ChangeNotifier {
  ReadingCompanionController({
    required this.config,
    DocumentAiSession? session,
    NxMicrophoneOpusStreamer? microphone,
    NxWavAudioPlayer? player,
  }) : session = session ?? DocumentAiSession(),
       microphone = microphone ?? NxMicrophoneOpusStreamer(),
       player = player ?? NxWavAudioPlayer() {
    this.session.onTextChunk = (packet) =>
        receive(packet.text, '${packet.streamIndex}');
    this.session.onTextEof = (_) {
      busy = false;
      _timeout?.cancel();
      _notify();
    };
    this.session.onError = (_) => _fail(
      'Could not reach the companion. Check your connection and try again.',
    );
    this.session.onAudioChunk = (packet) {
      if (speakReplies && !_disposed && _acceptResponses) {
        unawaited(
          this.player.addOpusPacket(packet.opus).catchError((Object _) {
            _fail('Audio playback failed. You can still read the reply.');
          }),
        );
      }
    };
    this.session.onAudioEof = (_) {
      if (speakReplies && _acceptResponses) {
        unawaited(this.player.flush().catchError((Object _) {}));
      }
    };
  }

  final DocumentAiSessionConfig config;
  final DocumentAiSession session;
  final NxMicrophoneOpusStreamer microphone;
  final NxWavAudioPlayer player;
  final messages = <ReadingMessage>[];
  bool busy = false;
  bool recording = false;
  bool speakReplies = false;
  String? error;
  bool _disposed = false;
  bool _held = false;
  bool _acceptResponses = false;
  String? _pendingTypedWire;
  String? _pendingTypedQuestion;
  int _generation = 0;
  Timer? _timeout;
  Timer? _recordingLimit;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _fail(String message) {
    if (_disposed) return;
    error = message;
    unawaited(cancel());
  }

  void _waitForReply() {
    busy = true;
    _timeout?.cancel();
    _timeout = Timer(
      const Duration(seconds: 90),
      () => _fail('The reply timed out. Try again.'),
    );
    _notify();
  }

  Future<bool> send(String raw, {String selection = ''}) async {
    final text = raw.trim();
    if (text.isEmpty || busy || recording || _disposed) return false;
    final generation = ++_generation;
    error = null;
    busy = true;
    _notify();
    try {
      await session.connect(config);
      if (_disposed || generation != _generation) return false;
      _acceptResponses = true;
      messages.add(ReadingMessage('user', text));
      final excerpt = selection.length > 6000
          ? selection.substring(0, 6000)
          : selection;
      final wire = excerpt.isEmpty
          ? text
          : 'Selected passage (reference text):\n${jsonEncode(excerpt)}\n\nQuestion: $text';
      _pendingTypedWire = wire;
      _pendingTypedQuestion = text;
      session.sendTextTurn(wire);
      _waitForReply();
      return true;
    } catch (_) {
      _fail('Could not send. Your question is still in the input box.');
      return false;
    }
  }

  Future<void> startRecording() async {
    if (busy || recording || _disposed) return;
    _held = true;
    final generation = ++_generation;
    error = null;
    busy = true;
    _notify();
    try {
      await player.stop();
      await session.connect(config);
      if (_disposed || !_held || generation != _generation) {
        busy = false;
        _notify();
        return;
      }
      session.beginAudioTurn();
      final started = await microphone.start(
        onOpusPacket: (packet) {
          if (_held && !_disposed && generation == _generation) {
            session.sendAudioPacket(packet);
          }
        },
        onError: (_) =>
            _fail('Microphone failed. Try again or type your question.'),
      );
      if (_disposed || !_held || generation != _generation) {
        await microphone.stop(flushRemainder: false);
        if (!_disposed) {
          busy = false;
          _notify();
        }
        return;
      }
      if (!started) {
        _fail('Allow microphone access to record a question.');
        return;
      }
      _acceptResponses = true;
      recording = true;
      busy = false;
      _recordingLimit = Timer(
        const Duration(seconds: 60),
        () => unawaited(stopRecording()),
      );
      _notify();
    } catch (_) {
      _fail('Could not start recording. Try typing instead.');
    }
  }

  Future<void> stopRecording() async {
    _held = false;
    _recordingLimit?.cancel();
    if (!recording) return;
    recording = false;
    busy = true;
    _notify();
    try {
      final remainder = await microphone.stop();
      if (_disposed || !_acceptResponses) return;
      for (final packet in remainder) {
        session.sendAudioPacket(packet);
      }
      session.endAudioTurn();
      _waitForReply();
    } catch (_) {
      _fail('Could not send the recording. Please try again.');
    }
  }

  Future<void> setSpeakReplies(bool value) async {
    speakReplies = value;
    if (!value) await player.stop();
    _notify();
  }

  Future<void> cancel() async {
    _generation++;
    _held = false;
    _acceptResponses = false;
    _timeout?.cancel();
    _recordingLimit?.cancel();
    recording = false;
    busy = false;
    _notify();
    await microphone.stop(flushRemainder: false);
    await player.stop();
    await session.disconnect();
  }

  void receive(String raw, String fallbackTurn) {
    if (_disposed || !_acceptResponses) return;
    var role = 'assistant';
    var text = raw;
    var turn = fallbackTurn;
    var delta = true;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        if (decoded['type'] != 'transcript' &&
            decoded['type'] != 'transcript-delta') {
          return;
        }
        role = decoded['role']?.toString() ?? 'assistant';
        text = decoded['text']?.toString() ?? '';
        turn = decoded['turnkey']?.toString() ?? fallbackTurn;
        delta =
            decoded['type'] == 'transcript-delta' &&
            decoded['ephemeral'] != true;
      }
    } catch (_) {
      /* Plain text is also supported by the socket protocol. */
    }
    if (text.trim().isEmpty || (role != 'user' && role != 'assistant')) return;
    if (role == 'user' && text == _pendingTypedWire) {
      text = _pendingTypedQuestion ?? text;
      _pendingTypedWire = null;
      _pendingTypedQuestion = null;
    }
    var index = messages.lastIndexWhere(
      (m) => m.role == role && m.turn == turn,
    );
    if (index < 0 && role == 'user') {
      index = messages.lastIndexWhere(
        (m) => m.role == role && m.turn == null && m.text == text,
      );
    }
    if (index >= 0) {
      messages[index] = ReadingMessage(
        role,
        delta && role == 'assistant' ? messages[index].text + text : text,
        turn: turn,
      );
    } else {
      messages.add(ReadingMessage(role, text, turn: turn));
    }
    if (messages.length > 100) messages.removeRange(0, messages.length - 100);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(
      cancel().whenComplete(() async {
        await microphone.dispose();
        await player.dispose();
      }),
    );
    super.dispose();
  }
}

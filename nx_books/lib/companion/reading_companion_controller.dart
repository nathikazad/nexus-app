import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nx_voice/nx_voice.dart';
import '../domain/book/reading_history.dart';
export '../domain/book/reading_history.dart';

/// One document conversation, shared by typed and recorded turns.
class ReadingCompanionController extends ChangeNotifier {
  ReadingCompanionController({
    required this.config,
    DocumentAiSession? session,
    NxMicrophoneOpusStreamer? microphone,
    this.hasNetwork,
  }) : session = session ?? DocumentAiSession(),
       microphone = microphone ?? NxMicrophoneOpusStreamer() {
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
    // Voice is input-only. Responses are rendered through the text callbacks.
  }

  final DocumentAiSessionConfig config;
  final Future<bool> Function()? hasNetwork;
  final DocumentAiSession session;
  final NxMicrophoneOpusStreamer microphone;
  final messages = <ReadingMessage>[];
  bool busy = false;
  bool recording = false;
  String? error;
  bool _disposed = false;
  bool _held = false;
  bool _acceptResponses = false;
  String? _pendingTypedWire;
  String? _pendingTypedQuestion;
  int _generation = 0;
  Timer? _timeout;
  Timer? _recordingLimit;
  int _responseStart = 0;
  bool syncing = false;

  Future<ReadingHistory?> syncHistory(
    Future<ReadingHistory> Function() fetch,
  ) async {
    if (_disposed || recording || syncing) return null;
    syncing = true;
    busy = true;
    _generation++;
    _acceptResponses = false;
    _timeout?.cancel();
    error = null;
    _notify();
    try {
      await session.disconnect();
      final history = await fetch();
      if (_disposed) return null;
      if (history.messages.isEmpty && messages.isNotEmpty) {
        throw StateError('The server has not saved this conversation yet');
      }
      messages
        ..clear()
        ..addAll(history.messages);
      _responseStart = messages.length;
      _pendingTypedWire = null;
      _pendingTypedQuestion = null;
      return history;
    } catch (_) {
      if (!_disposed) {
        error =
            'Could not sync the saved chat. Your current conversation is still here. Check your connection and try again.';
      }
      return null;
    } finally {
      syncing = false;
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> clearTranscript(Future<void> Function() clearSaved) async {
    if (busy || recording || _disposed) return false;
    busy = true;
    _acceptResponses = false;
    _notify();
    try {
      await session.disconnect();
      await clearSaved();
      if (_disposed) return true;
      messages.clear();
      _responseStart = 0;
      _pendingTypedWire = null;
      _pendingTypedQuestion = null;
      error = null;
      return true;
    } catch (_) {
      if (!_disposed) {
        error = 'Could not clear the saved conversation. Try again.';
      }
      return false;
    } finally {
      busy = false;
      _notify();
    }
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
    _responseStart = messages.length;
    error = null;
    busy = true;
    _notify();
    try {
      if (!await _canConnect()) return false;
      if (_disposed || generation != _generation) return false;
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

  Future<void> startRecording({String selection = ''}) async {
    if (busy || recording || _disposed) return;
    _held = true;
    final generation = ++_generation;
    _responseStart = messages.length;
    error = null;
    busy = true;
    _notify();
    try {
      if (!await _canConnect()) return;
      if (_disposed || !_held || generation != _generation) return;
      await session.connect(config.withSelection(selection));
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
    } catch (error, stack) {
      debugPrint(
        '[reading companion] recording startup failed: $error\n$stack',
      );
      _fail(
        'Could not start recording (${error.runtimeType}). Try typing instead.',
      );
    }
  }

  Future<bool> _canConnect() async {
    if (await hasNetwork?.call() ?? true) return true;
    busy = false;
    _held = false;
    error =
        'New AI replies require internet. Saved conversations remain available; your question has not been sent.';
    _notify();
    return false;
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
        if (decoded['type'] == 'error') {
          error = decoded['message'] is String
              ? decoded['message'] as String
              : 'Could not generate a reply. Please try again.';
          busy = false;
          _timeout?.cancel();
          _notify();
          return;
        }
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
    // Spaces and newlines are meaningful tokens in streamed Markdown.
    if (text.isEmpty || (role != 'user' && role != 'assistant')) return;
    if (role == 'user' && text == _pendingTypedWire) {
      text = _pendingTypedQuestion ?? text;
      _pendingTypedWire = null;
      _pendingTypedQuestion = null;
    }
    // The gateway sends raw tokens on stream 0 and the final transcript with
    // a server turnkey. Reconcile both within this request, never an old turn.
    var index = -1;
    for (var i = messages.length - 1; i >= _responseStart; i--) {
      if (messages[i].role == role) {
        index = i;
        break;
      }
    }
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
      }),
    );
    super.dispose();
  }
}

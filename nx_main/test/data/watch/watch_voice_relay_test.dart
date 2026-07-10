import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/voice/voice_socket_session.dart';
import 'package:nexus_voice_assistant/data/watch/watch_bridge_service.dart';
import 'package:nexus_voice_assistant/data/watch/watch_voice_relay.dart';
import 'package:nx_utils/nx_utils.dart';
import 'package:opus_dart/opus_dart.dart';

void main() {
  test('watch audio is resampled, encoded to Opus, and ended with EOF',
      () async {
    final bridge = _FakeWatchBridge();
    final socket = _FakeVoiceSocketSession();
    final relay = WatchVoiceRelay(
      bridge: bridge,
      socketSession: socket,
      inputEncoder: NxPcmOpusStreamEncoder(encodePcm16: _fakeEncode),
    )..start();
    relay.configure(socketUrl: 'wss://socket.nathikazad.com', userId: '1');

    bridge.emitStart();
    bridge.emitAudio(_pcmRamp(sampleCount: 2880));
    bridge.emitEof();
    await _drain(relay);

    expect(socket.config?.clientApp, 'nx_watch');
    expect(socket.config?.agentId, 'nx_watch');
    expect(socket.sentOpusPackets, isNotEmpty);
    expect(socket.audioEofCount, 1);
  });

  test('server Opus response is decoded, resampled, and sent to watch',
      () async {
    final bridge = _FakeWatchBridge();
    final socket = _FakeVoiceSocketSession();
    final pcm16 = _pcmRamp(sampleCount: 960);
    final relay = WatchVoiceRelay(
      bridge: bridge,
      socketSession: socket,
      decodeResponseOpus: (_) async => pcm16,
    )..start();

    socket.emitAudio(Uint8List.fromList([1, 2, 3]));
    socket.emitAudioEof();
    await _drain(relay);

    final playbackBytes =
        bridge.playbackChunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    expect(playbackBytes, 1440 * 2);
    expect(bridge.playbackEofCount, 1);
  });

  test('assistant text chunks append deltas and replace final transcript',
      () async {
    final bridge = _FakeWatchBridge();
    final socket = _FakeVoiceSocketSession();
    final relay = WatchVoiceRelay(bridge: bridge, socketSession: socket)
      ..start();

    socket.emitText(jsonEncode({
      'type': 'transcript-delta',
      'role': 'assistant',
      'text': 'hello',
    }));
    socket.emitText(jsonEncode({
      'type': 'transcript-delta',
      'role': 'assistant',
      'text': 'hello there',
      'ephemeral': true,
    }));
    socket.emitText(jsonEncode({
      'type': 'transcript',
      'role': 'assistant',
      'text': 'hello there',
    }));
    socket.emitText(jsonEncode({
      'type': 'transcript-delta',
      'role': 'user',
      'text': 'ignored',
    }));
    await _drain(relay);

    expect(bridge.textUpdates, [
      _TextUpdate('hello', replace: false),
      _TextUpdate('hello there', replace: true),
      _TextUpdate('hello there', replace: true),
    ]);
  });

  test('missing auth config reports watch-visible error', () async {
    final bridge = _FakeWatchBridge();
    final socket = _FakeVoiceSocketSession();
    final relay = WatchVoiceRelay(bridge: bridge, socketSession: socket)
      ..start();
    relay.configure(socketUrl: null, userId: null);

    bridge.emitStart();
    await _drain(relay);

    expect(socket.connectCount, 0);
    expect(bridge.errors.single, contains('Not logged in'));
  });
}

Future<void> _drain(WatchVoiceRelay relay) async {
  await Future<void>.delayed(Duration.zero);
  await relay.waitForIdle();
}

Uint8List _pcmRamp({required int sampleCount}) {
  final bytes = Uint8List(sampleCount * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < sampleCount; i++) {
    data.setInt16(i * 2, ((i * 31) % 28000) - 14000, Endian.little);
  }
  return bytes;
}

Future<List<Uint8List>> _fakeEncode(
  Uint8List pcmData, {
  int sampleRate = 16000,
  int channels = 1,
  FrameTime frameTime = FrameTime.ms60,
  bool fillUpLastFrame = true,
}) async {
  return [
    Uint8List.fromList([pcmData.length & 0xFF])
  ];
}

class _FakeWatchBridge implements WatchBridgeGateway {
  final _messageController = StreamController<String>.broadcast();
  final _audioStartController = StreamController<WatchAudioStart>.broadcast();
  final _audioController = StreamController<WatchAudioPacket>.broadcast();
  final _eofController = StreamController<WatchAudioEOF>.broadcast();

  final List<String> messages = [];
  final List<_TextUpdate> textUpdates = [];
  final List<String> statuses = [];
  final List<String> errors = [];
  final List<Uint8List> playbackChunks = [];
  int playbackEofCount = 0;

  @override
  Stream<String> get messageStream => _messageController.stream;

  @override
  Stream<WatchAudioStart> get audioStartStream => _audioStartController.stream;

  @override
  Stream<WatchAudioPacket> get audioStream => _audioController.stream;

  @override
  Stream<WatchAudioEOF> get eofStream => _eofController.stream;

  void emitStart() {
    _audioStartController.add(WatchAudioStart());
  }

  void emitAudio(Uint8List data) {
    _audioController.add(
      WatchAudioPacket(data: data, sampleRate: 24000, size: data.length),
    );
  }

  void emitEof() {
    _eofController.add(WatchAudioEOF(totalPackets: 1));
  }

  @override
  Future<bool> sendToWatch(String message) async {
    textUpdates.add(_TextUpdate(message, replace: false));
    return true;
  }

  @override
  Future<bool> sendTextUpdateToWatch(
    String text, {
    bool replace = false,
  }) async {
    messages.add(_TextUpdate(text, replace: replace).text);
    textUpdates.add(_TextUpdate(text, replace: replace));
    return true;
  }

  @override
  Future<bool> sendStatusToWatch(String status) async {
    statuses.add(status);
    return true;
  }

  @override
  Future<bool> sendErrorToWatch(String error) async {
    errors.add(error);
    return true;
  }

  @override
  Future<bool> sendPlaybackAudioToWatch(
    Uint8List pcm, {
    int sampleRate = 24000,
  }) async {
    playbackChunks.add(Uint8List.fromList(pcm));
    return true;
  }

  @override
  Future<bool> sendPlaybackEofToWatch() async {
    playbackEofCount++;
    return true;
  }
}

class _TextUpdate {
  const _TextUpdate(this.text, {required this.replace});

  final String text;
  final bool replace;

  @override
  bool operator ==(Object other) {
    return other is _TextUpdate &&
        other.text == text &&
        other.replace == replace;
  }

  @override
  int get hashCode => Object.hash(text, replace);

  @override
  String toString() {
    return '_TextUpdate(text: $text, replace: $replace)';
  }
}

class _FakeVoiceSocketSession implements VoiceSocketSessionPort {
  VoiceSocketSessionConfig? config;
  int connectCount = 0;
  int audioEofCount = 0;
  final List<Uint8List> sentOpusPackets = [];

  void Function(NxVoiceAudioChunk packet)? _onAudioChunk;
  void Function(NxVoiceAudioEof packet)? _onAudioEof;
  void Function(NxVoiceTextChunk packet)? _onTextChunk;
  void Function(Object error)? _onError;
  int _streamIndex = 0;
  VoiceSocketTurn? _activeTurn;
  VoiceSocketTurn? _lastTurn;
  bool _connected = false;

  @override
  set onAudioChunk(void Function(NxVoiceAudioChunk packet)? value) {
    _onAudioChunk = value;
  }

  @override
  set onAudioEof(void Function(NxVoiceAudioEof packet)? value) {
    _onAudioEof = value;
  }

  @override
  set onTextChunk(void Function(NxVoiceTextChunk packet)? value) {
    _onTextChunk = value;
  }

  @override
  set onTextEof(void Function(NxVoiceTextEof packet)? value) {}

  @override
  set onError(void Function(Object error)? value) {
    _onError = value;
  }

  @override
  bool get isConnected => _connected;

  @override
  int get streamIndex => _streamIndex;

  @override
  VoiceSocketTurn? get activeTurn => _activeTurn;

  @override
  VoiceSocketTurn? get lastTurn => _lastTurn;

  @override
  Future<void> connect(VoiceSocketSessionConfig config) async {
    connectCount++;
    this.config = config;
    _connected = true;
  }

  @override
  VoiceSocketTurn beginAudioTurn() {
    _streamIndex++;
    final turn = VoiceSocketTurn(
      streamIndex: _streamIndex,
      turn: NxVoiceAudioTurn.create(streamIndex: _streamIndex),
    );
    _activeTurn = turn;
    _lastTurn = turn;
    return turn;
  }

  @override
  void sendAudioPacket(Uint8List opus) {
    sentOpusPackets.add(Uint8List.fromList(opus));
  }

  @override
  void sendAudioPackets(Iterable<Uint8List> packets) {
    for (final packet in packets) {
      sendAudioPacket(packet);
    }
  }

  @override
  void endAudioTurn() {
    audioEofCount++;
    _activeTurn = null;
  }

  @override
  void sendTextTurn(String text) {}

  @override
  Future<void> disconnect({bool clearQueuedPackets = true}) async {
    _connected = false;
  }

  void emitAudio(Uint8List opus) {
    _onAudioChunk?.call(
      NxVoiceAudioChunk(
        opus: opus,
        streamIndex: _streamIndex,
        packetIndex: 0,
        meta: 0,
        turnRandom: 0,
        turnId: 0,
      ),
    );
  }

  void emitAudioEof() {
    _onAudioEof?.call(NxVoiceAudioEof(streamIndex: _streamIndex));
  }

  void emitText(String text) {
    _onTextChunk?.call(NxVoiceTextChunk(text: text, streamIndex: _streamIndex));
  }

  // Keeps the fake fully wired if tests need to surface socket errors later.
  void emitError(Object error) {
    _onError?.call(error);
  }
}

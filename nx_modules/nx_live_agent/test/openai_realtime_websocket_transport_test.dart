import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_live_agent/nx_live_agent.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('cancel drains accepted PCM before stopping native playback', () async {
    final channel = _FakeWebSocketChannel();
    final audio = _BlockingAudioDevice();
    final transport = OpenAiRealtimeWebSocketTransport(
      audioDevice: audio,
      connectWebSocket: ({required uri, required credential}) async => channel,
    );

    await transport.connect(
      credential: 'test-key',
      spec: const LiveAgentSpec(instructions: 'Test'),
      tools: const [],
    );
    audio.calls.clear();
    channel.receive({'type': 'response.created'});
    channel.receive({
      'type': 'response.output_audio.delta',
      'delta': base64Encode(Uint8List.fromList([1, 2, 3, 4])),
    });
    await pumpEventQueue();
    expect(audio.calls, ['add']);

    final cancellation = transport.cancelResponse();
    await pumpEventQueue();
    expect(audio.calls, ['add']);

    audio.releaseAdd();
    await cancellation;

    expect(audio.calls, ['add', 'addDone', 'stop']);
    expect(channel.sentTypes.last, 'response.cancel');
    await transport.dispose();
  });

  test('response.done waits for native playback to stop listening', () async {
    final channel = _FakeWebSocketChannel();
    final audio = _ControllableAudioDevice();
    final transport = OpenAiRealtimeWebSocketTransport(
      audioDevice: audio,
      connectWebSocket: ({required uri, required credential}) async => channel,
    );
    final phases = <LiveAgentEventType>[];
    final subscription = transport.events.listen(
      (event) => phases.add(event.type),
    );

    await transport.connect(
      credential: 'test-key',
      spec: const LiveAgentSpec(instructions: 'Test'),
      tools: const [],
    );
    channel.receive({'type': 'response.created'});
    channel.receive({
      'type': 'response.output_audio.delta',
      'delta': base64Encode(Uint8List.fromList([1, 2, 3, 4])),
    });
    channel.receive({'type': 'response.done', 'response': <String, Object?>{}});
    await pumpEventQueue();

    expect(phases, contains(LiveAgentEventType.speaking));
    expect(phases, isNot(contains(LiveAgentEventType.listening)));

    audio.reportPlaybackStopped();
    await pumpEventQueue();
    expect(phases.last, LiveAgentEventType.playbackStopped);

    await subscription.cancel();
    await transport.dispose();
  });
}

final class _BlockingAudioDevice implements LiveRealtimeAudioDevice {
  final calls = <String>[];
  final Completer<void> _addCompleter = Completer<void>();

  void releaseAdd() => _addCompleter.complete();

  @override
  void Function()? onPlaybackStarted;
  @override
  void Function()? onPlaybackStopped;
  @override
  void Function(Uint8List bytes)? onInputPcm16;

  @override
  Future<void> addPcm16(Uint8List bytes) async {
    calls.add('add');
    await _addCompleter.future;
    calls.add('addDone');
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<void> finishResponse() async => calls.add('finish');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> setInputMuted(bool muted) async {}
  @override
  Future<void> startInput() async => calls.add('startInput');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> stopInput() async => calls.add('stopInput');
}

final class _ControllableAudioDevice implements LiveRealtimeAudioDevice {
  bool _started = false;

  void reportPlaybackStopped() => onPlaybackStopped?.call();

  @override
  void Function()? onPlaybackStarted;
  @override
  void Function()? onPlaybackStopped;
  @override
  void Function(Uint8List bytes)? onInputPcm16;

  @override
  Future<void> addPcm16(Uint8List bytes) async {
    if (!_started) {
      _started = true;
      onPlaybackStarted?.call();
    }
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<void> finishResponse() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> setInputMuted(bool muted) async {}
  @override
  Future<void> startInput() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> stopInput() async {}
}

final class _FakeWebSocketChannel
    with StreamChannelMixin<Object?>
    implements WebSocketChannel {
  final StreamController<Object?> _incoming = StreamController<Object?>();
  late final _FakeWebSocketSink _sink = _FakeWebSocketSink(_handleSent);
  final sentTypes = <String>[];

  void receive(Map<String, Object?> event) => _incoming.add(jsonEncode(event));

  void _handleSent(Object? data) {
    final event = jsonDecode(data.toString()) as Map<String, dynamic>;
    sentTypes.add(event['type'].toString());
    if (event['type'] == 'session.update') {
      scheduleMicrotask(() => receive({'type': 'session.updated'}));
    }
  }

  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  String? get protocol => null;
  @override
  Future<void> get ready => Future<void>.value();
  @override
  WebSocketSink get sink => _sink;
  @override
  Stream<Object?> get stream => _incoming.stream;
}

final class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._onAdd);

  final void Function(Object? data) _onAdd;
  final Completer<void> _done = Completer<void>();

  @override
  void add(Object? data) => _onAdd(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<Object?> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

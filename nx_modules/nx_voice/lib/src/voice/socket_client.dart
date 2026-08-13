import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'packet_codec.dart';

class NxVoiceQueuedPacket {
  const NxVoiceQueuedPacket(this.bytes);

  final Uint8List bytes;
}

class NxVoiceSocketClient {
  NxVoiceSocketClient({
    this.maxQueueSize = 1000,
    this.reconnectDelay = const Duration(seconds: 3),
    this.maxReconnectAttempts = 5,
  });

  final int maxQueueSize;
  final Duration reconnectDelay;
  final int maxReconnectAttempts;

  WebSocketChannel? _channel;
  String? _url;
  Map<String, String>? _headers;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final List<NxVoiceQueuedPacket> _queue = [];

  void Function(NxVoicePacket packet)? onPacket;
  void Function(NxVoiceAudioChunk packet)? onAudioChunk;
  void Function(NxVoiceAudioEof packet)? onAudioEof;
  void Function(NxVoiceTextChunk packet)? onTextChunk;
  void Function(NxVoiceTextEof packet)? onTextEof;
  Future<String?> Function(NxVoiceDeviceRequest request)? onDeviceRequest;
  void Function(Object error)? onError;
  void Function()? onConnected;
  void Function()? onDisconnected;

  bool get isConnected => _isConnected;
  int get queuedPacketCount => _queue.length;

  Future<bool> connect(
    String url, {
    Map<String, String>? headers,
  }) async {
    _url = url;
    _headers = headers;
    return _connect();
  }

  Future<bool> _connect() async {
    final url = _url;
    if (url == null) return false;

    try {
      _channel = IOWebSocketChannel.connect(
        url,
        headers: _headers,
        pingInterval: const Duration(seconds: 20),
        connectTimeout: const Duration(seconds: 10),
      );
      await _channel!.ready;
      _isConnected = true;
      _reconnectAttempts = 0;
      onConnected?.call();
      _flushQueue();
      _channel!.stream.listen(
        (message) {
          unawaited(_handleMessage(message));
        },
        onError: (Object error) {
          onError?.call(error);
          _handleDisconnection();
        },
        onDone: _handleDisconnection,
        cancelOnError: true,
      );
      return true;
    } catch (error) {
      onError?.call(error);
      _isConnected = false;
      _scheduleReconnect();
      return false;
    }
  }

  void sendAudioChunk(
    Uint8List opus, {
    int streamIndex = 0,
    int packetIndex = 0,
    int? meta,
  }) {
    sendRaw(
      NxVoicePacketCodec.serializeAudioChunk(
        opus,
        streamIndex: streamIndex,
        packetIndex: packetIndex,
        meta: meta,
      ),
    );
  }

  void sendAudioEof({
    int streamIndex = 0,
    int? meta,
  }) {
    sendRaw(
      NxVoicePacketCodec.serializeAudioEof(
        streamIndex: streamIndex,
        meta: meta,
      ),
    );
  }

  void sendTextChunk(String text, {int streamIndex = 0}) {
    sendRaw(
      NxVoicePacketCodec.serializeTextChunk(
        text,
        streamIndex: streamIndex,
      ),
    );
  }

  void sendTextEof({int streamIndex = 0}) {
    sendRaw(NxVoicePacketCodec.serializeTextEof(streamIndex: streamIndex));
  }

  void sendTextTurn(String text, {int streamIndex = 0}) {
    sendTextChunk(text, streamIndex: streamIndex);
    sendTextEof(streamIndex: streamIndex);
  }

  void sendDeviceResponse({
    required int requestId,
    required String payload,
    int streamIndex = 0,
  }) {
    sendRaw(
      NxVoicePacketCodec.serializeDeviceResponse(
        requestId: requestId,
        payload: payload,
        streamIndex: streamIndex,
      ),
    );
  }

  void sendRaw(Uint8List bytes) {
    if (!_isConnected || _channel == null) {
      _queuePacket(bytes);
      return;
    }

    try {
      _channel!.sink.add(bytes);
    } catch (error) {
      onError?.call(error);
      _queuePacket(bytes);
      _handleDisconnection();
    }
  }

  Future<void> disconnect({bool clearQueuedPackets = true}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.sink.close();
      } catch (error) {
        onError?.call(error);
      }
    }

    if (clearQueuedPackets) {
      _queue.clear();
    }
    onDisconnected?.call();
  }

  void clearQueue() {
    _queue.clear();
  }

  Future<void> _handleMessage(Object message) async {
    if (message is String) {
      final packet = NxVoiceTextChunk(text: message, streamIndex: 0);
      onPacket?.call(packet);
      onTextChunk?.call(packet);
      return;
    }

    Uint8List? bytes;
    if (message is Uint8List) {
      bytes = message;
    } else if (message is List<int>) {
      bytes = Uint8List.fromList(message);
    }
    if (bytes == null) return;

    final packet = NxVoicePacketCodec.parse(bytes);
    if (packet == null) return;

    if (packet is NxVoiceDeviceRequest && onDeviceRequest != null) {
      final response = await onDeviceRequest!(packet);
      if (response != null) {
        sendDeviceResponse(
          requestId: packet.requestId,
          payload: response,
          streamIndex: packet.streamIndex,
        );
      }
      return;
    }

    onPacket?.call(packet);
    switch (packet) {
      case NxVoiceAudioChunk():
        onAudioChunk?.call(packet);
      case NxVoiceAudioEof():
        onAudioEof?.call(packet);
      case NxVoiceTextChunk():
        onTextChunk?.call(packet);
      case NxVoiceTextEof():
        onTextEof?.call(packet);
      case NxVoiceDeviceRequest():
      case NxVoiceUnknownPacket():
        break;
    }
  }

  void _queuePacket(Uint8List bytes) {
    if (_queue.length >= maxQueueSize) {
      _queue.removeAt(0);
    }
    _queue.add(NxVoiceQueuedPacket(Uint8List.fromList(bytes)));
  }

  void _flushQueue() {
    if (_queue.isEmpty || _channel == null) return;
    final pending = List<NxVoiceQueuedPacket>.from(_queue);
    _queue.clear();
    for (final packet in pending) {
      try {
        _channel!.sink.add(packet.bytes);
      } catch (error) {
        debugPrint('[nx_voice] failed to flush packet: $error');
        _queuePacket(packet.bytes);
        _handleDisconnection();
        return;
      }
    }
  }

  void _handleDisconnection() {
    if (!_isConnected && _channel == null) return;
    _isConnected = false;
    _channel = null;
    onDisconnected?.call();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_url == null || _reconnectAttempts >= maxReconnectAttempts) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay * (_reconnectAttempts + 1), () {
      _reconnectAttempts++;
      _connect();
    });
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../necklace/necklace_audio_codec.dart';
import '../necklace/necklace_device_protocol.dart';
import '../necklace/necklace_socket_port.dart';
export '../necklace/necklace_socket_port.dart'
    show SocketConnectionState, SocketSendStatus;

class _QueuedPacket {
  final Uint8List data;
  final int? index;

  _QueuedPacket(this.data, this.index);
}

class SocketClient implements NecklaceSocketPort {
  WebSocketChannel? _channel;
  String? _url;
  int _generation = 0;
  Map<String, String>? _accessHeaders;
  Future<Map<String, String>> Function(bool forceRefresh)? _authHeaders;
  bool _isConnected = false;
  Future<bool>? _connectFuture;
  final _audioCodec = NecklaceAudioCodec();
  final _deviceProtocol = NecklaceDeviceProtocol();
  // Packet queue for when socket is disconnected
  final List<_QueuedPacket> _packetQueue = [];
  static const int maxQueueSize =
      1000; // Limit queue size to prevent memory issues

  // Callback to forward packets from server to BLE
  Future<void> Function(Uint8List)? onPacketFromServer;
  set onAudioReceptionSummary(void Function(Map<String, dynamic>)? callback) {
    _audioCodec.onAudioReceptionSummary = callback;
  }

  /// Callback to handle device requests (e.g. take_photo). Returns response payload or null.
  Future<String?> Function(
          int requestId, String action, Map<String, dynamic> params)?
      onDeviceRequest;

  bool get isConnected => _isConnected;
  bool get isConnecting => _connectFuture != null;
  SocketConnectionState get connectionState {
    if (_isConnected) return SocketConnectionState.connected;
    if (_connectFuture != null) return SocketConnectionState.connecting;
    return SocketConnectionState.disconnected;
  }

  int get queuedPacketCount => _packetQueue.length;

  Future<bool> connect(
    String url, {
    Map<String, String>? headers,
    Future<Map<String, String>> Function(bool forceRefresh)? authHeaders,
  }) async {
    final metadata = {
      for (final entry in (headers ?? <String, String>{}).entries)
        entry.key.toLowerCase(): entry.value
    };
    final domain = int.tryParse(metadata['x-domain-id'] ?? '');
    if (metadata.containsKey('x-domain-id') &&
        (domain == null || domain <= 0)) {
      await disconnect();
      throw StateError('Domain ID must be positive when supplied.');
    }
    final closing = disconnect();
    final generation = _generation;
    await closing;
    if (generation != _generation) return false;
    _accessHeaders = Map<String, String>.from(headers ?? {});
    _authHeaders = authHeaders;
    _url = url;
    return ensureConnected(reason: 'connect');
  }

  Future<bool> ensureConnected({String reason = 'ensureConnected'}) {
    if (_isConnected && _channel != null) {
      return Future.value(true);
    }
    if (_connectFuture != null) {
      debugPrint("[Socket] Connect already in progress reason=$reason");
      return _connectFuture!;
    }

    debugPrint("[Socket] Starting connection reason=$reason");
    final future = _connect();
    _connectFuture = future;
    return future.whenComplete(() {
      if (identical(_connectFuture, future)) {
        _connectFuture = null;
      }
    });
  }

  Future<bool> _connect({bool forceRefresh = false}) async {
    if (_url == null) {
      debugPrint("[Socket] No URL provided");
      return false;
    }

    final generation = _generation;
    final url = _url!;
    final accessHeaders = _accessHeaders;
    final authHeaders = _authHeaders;
    WebSocketChannel? channel;
    try {
      debugPrint("[Socket] Connecting to $_url...");

      final headers = <String, String>{
        ...?await authHeaders?.call(forceRefresh),
        ...?accessHeaders,
      };
      if (generation != _generation) return false;
      channel = IOWebSocketChannel.connect(
        url,
        headers: headers,
        pingInterval: const Duration(seconds: 20),
        connectTimeout: const Duration(seconds: 10),
      );

      _channel = channel;
      await channel.ready;
      if (generation != _generation) {
        await channel.sink.close();
        return false;
      }
      _isConnected = true;

      debugPrint("[Socket] Connected to $_url");

      // Listen for messages from server
      channel.stream.listen(
        (message) async {
          if (generation != _generation) return;
          if (message is Uint8List) {
            // Intercept DEVICE_REQUEST packets - handle and respond, don't forward to BLE
            if (await _deviceProtocol.handle(message,
                isCurrent: () => generation == _generation,
                respond: sendDeviceResponsePacket,
                onDeviceRequest: onDeviceRequest)) {
              return;
            }
            if (generation != _generation) return;
            final blePayload = _audioCodec.decode(message);
            // Text/progress/control frames must never enter the firmware Opus parser.
            if (blePayload == null) return;
            if (onPacketFromServer != null) {
              onPacketFromServer!(blePayload).catchError((e) {
                debugPrint("[Socket] Error forwarding packet to BLE: $e");
              });
            } else {
              debugPrint("[Socket] No onPacketFromServer callback");
            }
          } else {
            debugPrint("[Socket] Received: $message");
          }
        },
        onError: (error) {
          if (generation != _generation) return;
          debugPrint("[Socket] Error: $error");
          _handleDisconnection();
        },
        onDone: () {
          if (generation != _generation) return;
          debugPrint("[Socket] Connection closed");
          _handleDisconnection();
        },
        cancelOnError: true,
      );

      // Send queued packets after the response listener is active.
      _flushPacketQueue();

      return true;
    } catch (e) {
      if (generation != _generation) return false;
      unawaited(channel?.sink.close());
      if (!forceRefresh && authHeaders != null) {
        debugPrint('[Socket] Initial connection failed; refreshing session');
        return _connect(forceRefresh: true);
      }
      debugPrint("[Socket] Connection failed: $e");
      _isConnected = false;
      _channel = null;
      return false;
    }
  }

  SocketSendStatus sendPacket(Uint8List data, {int? index}) {
    // If not connected, queue the packet
    if (!_isConnected || _channel == null) {
      _queuePacket(data, index);
      return SocketSendStatus.queuedNoConnection;
    }

    try {
      _sendPacketData(data, index);
      return SocketSendStatus.sent;
    } catch (e) {
      debugPrint("[Socket] Send error: $e");
      // Queue the packet if send fails
      _queuePacket(data, index);
      _handleDisconnection();
      return SocketSendStatus.queuedAfterSendFailure;
    }
  }

  void _sendPacketData(Uint8List data, int? index) {
    if (index != null) {
      // Format: [header_type 2B][index 4B] + [payload]. OPUS_AUDIO_PACKET = 0x0001
      const int OPUS_AUDIO_PACKET = 0x0001;
      final packet = Uint8List(6 + data.length);
      final byteData = ByteData.view(packet.buffer);
      byteData.setUint16(0, OPUS_AUDIO_PACKET, Endian.little);
      byteData.setUint32(2, index, Endian.little);
      packet.setRange(6, 6 + data.length, data);
      _channel!.sink.add(packet);
    } else {
      // Send as binary data without index
      _channel!.sink.add(data);
    }
  }

  void _queuePacket(Uint8List data, int? index) {
    // Never retain packets without an explicitly selected session.
    if (_url == null) return;
    // Limit queue size to prevent memory issues
    if (_packetQueue.length >= maxQueueSize) {
      debugPrint(
          "[Socket] Queue full (${_packetQueue.length} packets), dropping oldest packet");
      _packetQueue.removeAt(0);
    }

    // Create a copy of the data to avoid issues if the original is modified
    final dataCopy = Uint8List.fromList(data);
    _packetQueue.add(_QueuedPacket(dataCopy, index));

    if (_packetQueue.length == 1) {
      debugPrint("[Socket] Queueing packet (queue size: 1)");
    } else if (_packetQueue.length % 100 == 0) {
      debugPrint("[Socket] Queue size: ${_packetQueue.length} packets");
    }
  }

  void _flushPacketQueue() {
    if (_packetQueue.isEmpty) {
      return;
    }

    final queueSize = _packetQueue.length;
    debugPrint("[Socket] Flushing $queueSize queued packets...");

    try {
      for (final packet in _packetQueue) {
        _sendPacketData(packet.data, packet.index);
      }

      debugPrint("[Socket] Successfully sent $queueSize queued packets");
      _packetQueue.clear();
    } catch (e) {
      debugPrint("[Socket] Error flushing queue: $e");
      // Keep remaining packets in queue for next connection attempt
      _handleDisconnection();
    }
  }

  void sendText(String message) {
    if (!_isConnected || _channel == null) {
      debugPrint("[Socket] Cannot send: not connected");
      return;
    }

    try {
      _channel!.sink.add(message);
    } catch (e) {
      debugPrint("[Socket] Send error: $e");
      _handleDisconnection();
    }
  }

  /// Send a text packet to the server.
  /// Format: [header_type 2B][index 4B][packet_size 2B][text_bytes (N bytes)]
  /// Header type for TEXT_PACKET is 0x0002
  void sendTextPacket(String text, int index) {
    if (!_isConnected || _channel == null) {
      debugPrint("[Socket] Cannot send text packet: not connected");
      return;
    }

    try {
      const int TEXT_PACKET = 0x0002;
      final utf8Bytes = utf8.encode(text);
      final packetSize = utf8Bytes.length;

      // Format: [header_type 2B][index 4B][packet_size 2B][text_bytes (N bytes)]
      final packet = Uint8List(8 + packetSize);
      final byteData = ByteData.view(packet.buffer);
      byteData.setUint16(0, TEXT_PACKET, Endian.little);
      byteData.setUint32(2, index, Endian.little);
      byteData.setUint16(6, packetSize, Endian.little);
      packet.setRange(8, 8 + packetSize, utf8Bytes);

      _channel!.sink.add(packet);
      debugPrint(
          "[Socket] Sent text packet #$index: ${text.length} chars (${packetSize} bytes)");
    } catch (e) {
      debugPrint("[Socket] Error sending text packet: $e");
      _handleDisconnection();
    }
  }

  /// Send an image packet to the server.
  /// Format: [header_type 2B][index 4B][packet_size 2B][payload (N bytes)]
  /// Header type for IMAGE_PACKET is 0x0003
  /// Payload is raw BLE file TX packet: [0x00, 0x01, pkt_num, total_pkts, filename\0, chunk_data...]
  void sendImagePacket(Uint8List data, int index) {
    const int IMAGE_PACKET = 0x0003;
    final packetSize = data.length;

    // Format: [header_type 2B][index 4B][packet_size 2B][payload]
    final packet = Uint8List(8 + packetSize);
    final byteData = ByteData.view(packet.buffer);
    byteData.setUint16(0, IMAGE_PACKET, Endian.little);
    byteData.setUint32(2, index, Endian.little);
    byteData.setUint16(6, packetSize, Endian.little);
    packet.setRange(8, 8 + packetSize, data);

    if (!_isConnected || _channel == null) {
      _queuePacket(
          packet, null); // index=null so full packet sent as-is when flushed
      return;
    }

    try {
      _channel!.sink.add(packet);
    } catch (e) {
      debugPrint("[Socket] Error sending image packet: $e");
      _queuePacket(packet, null);
      _handleDisconnection();
    }
  }

  static const int _DEVICE_RESPONSE = 0x0005;

  /// Send DEVICE_RESPONSE to server.
  /// Format: [header 2B][index 4B][request_id 4B][payload_size 2B][payload]
  void sendDeviceResponsePacket(int requestId, String payload) {
    if (!_isConnected || _channel == null) {
      debugPrint("[Socket] Cannot send device response: not connected");
      return;
    }
    try {
      final payloadBytes = utf8.encode(payload);
      final packetSize = payloadBytes.length;
      final packet = Uint8List(12 + packetSize);
      final byteData = ByteData.view(packet.buffer);
      byteData.setUint16(0, _DEVICE_RESPONSE, Endian.little);
      byteData.setUint32(2, 0, Endian.little); // index
      byteData.setUint32(6, requestId, Endian.little);
      byteData.setUint16(10, packetSize, Endian.little);
      packet.setRange(12, 12 + packetSize, payloadBytes);
      _channel!.sink.add(packet);
      debugPrint("[Socket] Sent DEVICE_RESPONSE for request $requestId");
    } catch (e) {
      debugPrint("[Socket] Error sending device response: $e");
      _handleDisconnection();
    }
  }

  /// Send an AUDIO_EOF packet (end of mic / voice turn, ForceEndpoint on server).
  /// Format: [header_type 2B][index 4B]. Header type 0xFFFC.
  void sendAudioEofPacket(int index) {
    if (!_isConnected || _channel == null) {
      debugPrint("[Socket] Cannot send AUDIO_EOF packet: not connected");
      return;
    }

    try {
      const int AUDIO_EOF_PACKET = 0xFFFC;

      // Format: [header_type 2B][index 4B]
      final packet = Uint8List(6);
      final byteData = ByteData.view(packet.buffer);
      byteData.setUint16(0, AUDIO_EOF_PACKET, Endian.little);
      byteData.setUint32(2, index, Endian.little);

      _channel!.sink.add(packet);
      debugPrint("[Socket] Sent AUDIO_EOF packet #$index");
    } catch (e) {
      debugPrint("[Socket] Error sending AUDIO_EOF packet: $e");
      _handleDisconnection();
    }
  }

  /// Send a text-only EOF (end of typed message). Does not trigger voice/STT.
  /// Format: [header_type 2B][index 4B]. Header type 0x0006 (TEXT_EOF).
  void sendTextEofPacket(int index) {
    if (!_isConnected || _channel == null) {
      debugPrint("[Socket] Cannot send text EOF packet: not connected");
      return;
    }

    try {
      const int TEXT_EOF_PACKET = 0x0006;

      final packet = Uint8List(6);
      final byteData = ByteData.view(packet.buffer);
      byteData.setUint16(0, TEXT_EOF_PACKET, Endian.little);
      byteData.setUint32(2, index, Endian.little);

      _channel!.sink.add(packet);
      debugPrint("[Socket] Sent TEXT_EOF packet #$index");
    } catch (e) {
      debugPrint("[Socket] Error sending TEXT_EOF packet: $e");
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    if (!_isConnected) return;

    _isConnected = false;
    _channel = null;
  }

  Future<void> disconnect({bool clearQueuedPackets = true}) async {
    ++_generation;
    _isConnected = false;
    _connectFuture = null;
    _url = null;
    _accessHeaders = null;
    _authHeaders = null;
    final channel = _channel;
    _channel = null;
    if (clearQueuedPackets) _packetQueue.clear();
    _audioCodec.reset();
    try {
      await channel?.sink.close();
    } catch (e) {
      debugPrint('[Socket] Error closing: $e');
    }
  }

  /// Clear the packet queue (useful for testing or when you want to drop queued packets)
  void clearQueue() {
    final count = _packetQueue.length;
    _packetQueue.clear();
    if (count > 0) {
      debugPrint("[Socket] Cleared $count queued packets");
    }
  }
}

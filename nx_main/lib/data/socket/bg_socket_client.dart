import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _QueuedPacket {
  final Uint8List data;
  final int? index;

  _QueuedPacket(this.data, this.index);
}

class SocketClient {
  static const int _opusAudioPacket = 0x0001;
  static const int _audioEofPacket = 0xFFFC;

  WebSocketChannel? _channel;
  String? _url;
  Map<String, String>? _accessHeaders;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _audioReceiveActive = false;
  int _audioReceivePacketCount = 0;
  int _audioReceiveByteCount = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);

  // Packet queue for when socket is disconnected
  final List<_QueuedPacket> _packetQueue = [];
  static const int maxQueueSize =
      1000; // Limit queue size to prevent memory issues

  // Callback to forward packets from server to BLE
  Future<void> Function(Uint8List)? onPacketFromServer;

  /// Callback to handle device requests (e.g. take_photo). Returns response payload or null.
  Future<String?> Function(
          int requestId, String action, Map<String, dynamic> params)?
      onDeviceRequest;

  bool get isConnected => _isConnected;
  int get queuedPacketCount => _packetQueue.length;

  Future<bool> connect(String url, {Map<String, String>? headers}) async {
    _accessHeaders = headers;
    if (_isConnected && _url == url) {
      debugPrint("[Socket] Already connected to $url");
      return true;
    }

    _url = url;
    return await _connect();
  }

  Future<bool> _connect() async {
    if (_url == null) {
      debugPrint("[Socket] No URL provided");
      return false;
    }

    try {
      debugPrint("[Socket] Connecting to $_url...");

      _channel = IOWebSocketChannel.connect(
        _url!,
        headers: _accessHeaders,
        pingInterval: const Duration(seconds: 20),
        connectTimeout: const Duration(seconds: 10),
      );

      await _channel!.ready;
      _isConnected = true;
      _reconnectAttempts = 0;

      debugPrint("[Socket] Connected to $_url");

      // Send queued packets if any
      _flushPacketQueue();

      // Listen for messages from server
      _channel!.stream.listen(
        (message) async {
          if (message is Uint8List) {
            // Intercept DEVICE_REQUEST packets - handle and respond, don't forward to BLE
            if (await _handleDeviceRequestIfNeeded(message)) {
              return;
            }
            final blePayload = _serverAudioPacketToBlePayload(message);
            // Forward server audio payloads to BLE after removing the WebSocket
            // protocol envelope. Non-audio binary packets are forwarded as-is.
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
          debugPrint("[Socket] Error: $error");
          _handleDisconnection();
        },
        onDone: () {
          debugPrint("[Socket] Connection closed");
          _handleDisconnection();
        },
        cancelOnError: true,
      );

      return true;
    } catch (e) {
      debugPrint("[Socket] Connection failed: $e");
      _isConnected = false;
      _scheduleReconnect();
      return false;
    }
  }

  void sendPacket(Uint8List data, {int? index}) {
    // If not connected, queue the packet
    if (!_isConnected || _channel == null) {
      _queuePacket(data, index);
      return;
    }

    try {
      _sendPacketData(data, index);
    } catch (e) {
      debugPrint("[Socket] Send error: $e");
      // Queue the packet if send fails
      _queuePacket(data, index);
      _handleDisconnection();
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

  Uint8List _serverAudioPacketToBlePayload(Uint8List packet) {
    if (packet.length < 2) return packet;

    final byteData = ByteData.sublistView(packet);
    final headerType = byteData.getUint16(0, Endian.little);

    if (headerType == _audioEofPacket) {
      _finishAudioReception();
      return Uint8List.fromList([
        _audioEofPacket & 0xFF,
        (_audioEofPacket >> 8) & 0xFF,
      ]);
    }

    if (headerType != _opusAudioPacket || packet.length < 11) {
      return packet;
    }

    _recordAudioReception(packet.length);

    final streamIndex = byteData.getUint32(2, Endian.little);
    final packetIndex = packet[8];
    final opusSize = byteData.getUint16(9, Endian.little);
    final opusStart = 11;
    final opusEnd = opusStart + opusSize;
    if (opusEnd > packet.length) {
      debugPrint(
        "[Socket] Incomplete server audio packet: need $opusEnd got ${packet.length}",
      );
      return packet;
    }

    final meta = (streamIndex & 0x07) | ((packetIndex & 0x1FFF) << 3);
    final blePayload = Uint8List(4 + opusSize);
    final out = ByteData.sublistView(blePayload);
    out.setUint16(0, opusSize, Endian.little);
    out.setUint16(2, meta, Endian.little);
    blePayload.setRange(4, 4 + opusSize, packet, opusStart);
    return blePayload;
  }

  String _utcNow() => DateTime.now().toUtc().toIso8601String();

  void _recordAudioReception(int packetBytes) {
    if (!_audioReceiveActive) {
      _audioReceiveActive = true;
      _audioReceivePacketCount = 0;
      _audioReceiveByteCount = 0;
      debugPrint("[BLE BG] ${_utcNow()} UTC audio packets reception started");
    }
    _audioReceivePacketCount++;
    _audioReceiveByteCount += packetBytes;
  }

  void _finishAudioReception() {
    if (!_audioReceiveActive) return;
    // Count WebSocket wire EOF packet: [header_type 2B][stream_index 4B].
    _audioReceivePacketCount++;
    _audioReceiveByteCount += 6;
    debugPrint(
      "[BLE BG] ${_utcNow()} UTC audio packets reception finished "
      "$_audioReceivePacketCount packets, $_audioReceiveByteCount bytes",
    );
    _audioReceiveActive = false;
    _audioReceivePacketCount = 0;
    _audioReceiveByteCount = 0;
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

  static const int _DEVICE_REQUEST = 0x0004;
  static const int _DEVICE_RESPONSE = 0x0005;

  /// Handle DEVICE_REQUEST from server. Returns true if handled (don't forward to BLE).
  Future<bool> _handleDeviceRequestIfNeeded(Uint8List message) async {
    if (message.length < 12) return false;
    final byteData = ByteData.view(
        message.buffer, message.offsetInBytes, message.lengthInBytes);
    final headerType = byteData.getUint16(4, Endian.little);
    if (headerType != _DEVICE_REQUEST) return false;

    final requestId = byteData.getUint32(6, Endian.little);
    final payloadSize = byteData.getUint16(10, Endian.little);
    if (message.length < 12 + payloadSize) return false;

    final payloadStr = utf8.decode(message.sublist(12, 12 + payloadSize));
    try {
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final action = payload['action'] as String?;
      if (action == null) return false;

      if (action == 'get_gps') {
        // Fake GPS: always return same coordinates (SF)
        final result = jsonEncode({
          'lat': 37.7749,
          'lng': -122.4194,
          'accuracy': 10.0,
        });
        sendDeviceResponsePacket(requestId, result);
        debugPrint("[Socket] Handled get_gps request, sent fake GPS");
        return true;
      }

      const deviceActions = [
        'take_photo',
        'get_camera_status',
        'start_record',
        'stop_record',
        'set_record_period',
        'get_battery',
        'vibrate',
        'power_cycle',
      ];
      if (deviceActions.contains(action) && onDeviceRequest != null) {
        final result = await onDeviceRequest!(requestId, action, payload);
        if (result != null) {
          sendDeviceResponsePacket(requestId, result);
          debugPrint("[Socket] Handled $action request via onDeviceRequest");
          return true;
        }
      }
    } catch (e) {
      debugPrint("[Socket] Error handling device request: $e");
    }
    return false;
  }

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
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint("[Socket] Max reconnect attempts reached");
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay * (_reconnectAttempts + 1), () {
      _reconnectAttempts++;
      debugPrint("[Socket] Reconnecting (attempt $_reconnectAttempts)...");
      _connect();
    });
  }

  Future<void> disconnect({bool clearQueuedPackets = true}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;

    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        debugPrint("[Socket] Error closing: $e");
      }
      _channel = null;
    }

    if (clearQueuedPackets) {
      _packetQueue.clear();
    }
    debugPrint(
        "[Socket] Disconnected (${_packetQueue.length} packets in queue)");
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

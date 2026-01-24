import 'dart:async';
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
  WebSocketChannel? _channel;
  String? _url;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);
  
  // Packet queue for when socket is disconnected
  final List<_QueuedPacket> _packetQueue = [];
  static const int maxQueueSize = 1000; // Limit queue size to prevent memory issues
  
  // Callback to forward packets from server to BLE
  Future<void> Function(Uint8List)? onPacketFromServer;

  bool get isConnected => _isConnected;
  int get queuedPacketCount => _packetQueue.length;

  Future<bool> connect(String url) async {
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
        (message) {
          if (message is Uint8List) {
            // Forward binary packets from server to BLE
            debugPrint("[Socket] Received binary packet: ${message.length} bytes");
            if (onPacketFromServer != null) {
              onPacketFromServer!(message).catchError((e) {
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
      // Format: [4 bytes index (uint32 little-endian)] + [payload data]
      final indexBytes = Uint8List(4);
      final byteData = ByteData.view(indexBytes.buffer);
      byteData.setUint32(0, index, Endian.little);
      
      // Combine index + payload
      final combined = Uint8List(4 + data.length);
      combined.setRange(0, 4, indexBytes);
      combined.setRange(4, 4 + data.length, data);
      
      _channel!.sink.add(combined);
    } else {
      // Send as binary data without index
      _channel!.sink.add(data);
    }
  }
  
  void _queuePacket(Uint8List data, int? index) {
    // Limit queue size to prevent memory issues
    if (_packetQueue.length >= maxQueueSize) {
      debugPrint("[Socket] Queue full (${_packetQueue.length} packets), dropping oldest packet");
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

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        debugPrint("[Socket] Error closing: $e");
      }
      _channel = null;
    }
    
    _isConnected = false;
    debugPrint("[Socket] Disconnected (${_packetQueue.length} packets in queue)");
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


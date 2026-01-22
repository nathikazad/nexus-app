import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class BackgroundSocketClient {
  WebSocketChannel? _channel;
  String? _url;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);

  bool get isConnected => _isConnected;

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

      // Listen for messages from server
      _channel!.stream.listen(
        (message) {
          debugPrint("[Socket] Received: $message");
          if (message == "ping") {
            // Respond to ping
            _channel?.sink.add([0x8A, 0x00]); // Pong frame
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

  void sendPacket(Uint8List data) {
    if (!_isConnected || _channel == null) {
      debugPrint("[Socket] Cannot send: not connected");
      return;
    }

    try {
      // Send as binary data
      _channel!.sink.add(data);
    } catch (e) {
      debugPrint("[Socket] Send error: $e");
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
    debugPrint("[Socket] Disconnected");
  }
}


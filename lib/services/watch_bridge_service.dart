import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Service to handle communication between Flutter and iOS/watchOS
class WatchBridgeService {
  static final WatchBridgeService instance = WatchBridgeService._();
  
  WatchBridgeService._();
  
  static const _channel = MethodChannel('com.nexus/watch_bridge');
  
  final _messageController = StreamController<String>.broadcast();
  
  /// Stream of messages received from iOS/Watch
  Stream<String> get messageStream => _messageController.stream;
  
  bool _isInitialized = false;
  
  /// Initialize the watch bridge service
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (!Platform.isIOS) {
      print('[WatchBridge] Not iOS, skipping initialization');
      return;
    }
    
    // Set up handler for messages from iOS
    _channel.setMethodCallHandler(_handleMethodCall);
    
    _isInitialized = true;
    print('[WatchBridge] Service initialized');
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'messageFromWatch':
        final message = call.arguments as String;
        print('[WatchBridge] Received message from iOS/Watch: $message');
        _messageController.add(message);
        return true;
      default:
        throw PlatformException(
          code: 'NOT_IMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }
  
  /// Send a ping to iOS and expect a pong response
  Future<String?> ping() async {
    if (!Platform.isIOS) {
      print('[WatchBridge] Not iOS, ping not available');
      return null;
    }
    
    try {
      final result = await _channel.invokeMethod<String>('ping');
      print('[WatchBridge] Ping result: $result');
      return result;
    } on PlatformException catch (e) {
      print('[WatchBridge] Ping failed: ${e.message}');
      return null;
    }
  }
  
  /// Send a message to the Watch (via iOS)
  Future<bool> sendToWatch(String message) async {
    if (!Platform.isIOS) {
      print('[WatchBridge] Not iOS, sendToWatch not available');
      return false;
    }
    
    try {
      final result = await _channel.invokeMethod<bool>('sendToWatch', message);
      return result ?? false;
    } on PlatformException catch (e) {
      print('[WatchBridge] sendToWatch failed: ${e.message}');
      return false;
    }
  }
  
  void dispose() {
    _messageController.close();
  }
}


import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Audio packet data from watch
class WatchAudioPacket {
  final Uint8List data;
  final int sampleRate;
  final int size;
  final DateTime timestamp;
  
  WatchAudioPacket({
    required this.data,
    required this.sampleRate,
    required this.size,
  }) : timestamp = DateTime.now();
}

/// EOF event when watch stops recording
class WatchAudioEOF {
  final int totalPackets;
  final DateTime timestamp;
  
  WatchAudioEOF({
    required this.totalPackets,
  }) : timestamp = DateTime.now();
}

/// Service to handle communication between Flutter and iOS/watchOS
class WatchBridgeService {
  static final WatchBridgeService instance = WatchBridgeService._();
  
  WatchBridgeService._();
  
  static const _channel = MethodChannel('com.nexus/watch_bridge');
  
  final _messageController = StreamController<String>.broadcast();
  final _audioController = StreamController<WatchAudioPacket>.broadcast();
  final _eofController = StreamController<WatchAudioEOF>.broadcast();
  
  /// Stream of text messages received from iOS/Watch
  Stream<String> get messageStream => _messageController.stream;
  
  /// Stream of audio packets received from Watch
  Stream<WatchAudioPacket> get audioStream => _audioController.stream;
  
  /// Stream of EOF events when watch stops recording
  Stream<WatchAudioEOF> get eofStream => _eofController.stream;
  
  bool _isInitialized = false;
  int _packetCount = 0;
  
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
        
      case 'audioFromWatch':
        final args = call.arguments as Map;
        final data = args['data'] as Uint8List;
        final sampleRate = args['sampleRate'] as int;
        final size = args['size'] as int;
        
        _packetCount++;
        print('[WatchBridge] 📦 Audio packet #$_packetCount received: $size bytes @ ${sampleRate}Hz');
        
        final packet = WatchAudioPacket(
          data: data,
          sampleRate: sampleRate,
          size: size,
        );
        _audioController.add(packet);
        return true;
        
      case 'audioEOFFromWatch':
        final args = call.arguments as Map;
        final totalPackets = args['totalPackets'] as int;
        
        print('[WatchBridge] 🏁 EOF received - total packets: $totalPackets (received: $_packetCount)');
        
        final eof = WatchAudioEOF(totalPackets: totalPackets);
        _eofController.add(eof);
        return true;
        
      default:
        throw PlatformException(
          code: 'NOT_IMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }
  
  /// Reset packet count (call when starting new recording)
  void resetPacketCount() {
    _packetCount = 0;
  }
  
  /// Get current packet count
  int get packetCount => _packetCount;
  
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
    _audioController.close();
    _eofController.close();
  }
}


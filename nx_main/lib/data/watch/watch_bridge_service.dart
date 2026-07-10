import 'dart:async';
import 'dart:io';
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

/// Start event when watch begins a new recording turn.
class WatchAudioStart {
  final DateTime timestamp;

  WatchAudioStart() : timestamp = DateTime.now();
}

abstract interface class WatchBridgeGateway {
  Stream<String> get messageStream;
  Stream<WatchAudioStart> get audioStartStream;
  Stream<WatchAudioPacket> get audioStream;
  Stream<WatchAudioEOF> get eofStream;

  Future<bool> sendToWatch(String message);
  Future<bool> sendTextUpdateToWatch(
    String text, {
    bool replace,
  });
  Future<bool> sendStatusToWatch(String status);
  Future<bool> sendErrorToWatch(String error);
  Future<bool> sendPlaybackAudioToWatch(
    Uint8List pcm, {
    int sampleRate,
  });
  Future<bool> sendPlaybackEofToWatch();
}

/// Service to handle communication between Flutter and iOS/watchOS
class WatchBridgeService implements WatchBridgeGateway {
  static final WatchBridgeService instance = WatchBridgeService._();

  WatchBridgeService._();

  static const _channel = MethodChannel('com.nexus/watch_bridge');

  final _messageController = StreamController<String>.broadcast();
  final _audioStartController = StreamController<WatchAudioStart>.broadcast();
  final _audioController = StreamController<WatchAudioPacket>.broadcast();
  final _eofController = StreamController<WatchAudioEOF>.broadcast();

  /// Stream of text messages received from iOS/Watch
  @override
  Stream<String> get messageStream => _messageController.stream;

  /// Stream of watch recording start events.
  @override
  Stream<WatchAudioStart> get audioStartStream => _audioStartController.stream;

  /// Stream of audio packets received from Watch
  @override
  Stream<WatchAudioPacket> get audioStream => _audioController.stream;

  /// Stream of EOF events when watch stops recording
  @override
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

      case 'audioStartFromWatch':
        print('[WatchBridge] 🎙️ Audio start received');
        resetPacketCount();
        _audioStartController.add(WatchAudioStart());
        return true;

      case 'audioFromWatch':
        final args = call.arguments as Map;
        final data = args['data'] as Uint8List;
        final sampleRate = args['sampleRate'] as int;
        final size = args['size'] as int;

        _packetCount++;
        print(
            '[WatchBridge] 📦 Audio packet #$_packetCount received: $size bytes @ ${sampleRate}Hz');

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

        print(
            '[WatchBridge] 🏁 EOF received - total packets: $totalPackets (received: $_packetCount)');

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
  @override
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

  @override
  Future<bool> sendTextUpdateToWatch(
    String text, {
    bool replace = false,
  }) {
    return _invokeWatchBool('sendTextUpdateToWatch', {
      'text': text,
      'mode': replace ? 'replace' : 'append',
    });
  }

  @override
  Future<bool> sendStatusToWatch(String status) {
    return _invokeWatchBool('sendStatusToWatch', status);
  }

  @override
  Future<bool> sendErrorToWatch(String error) {
    return _invokeWatchBool('sendErrorToWatch', error);
  }

  @override
  Future<bool> sendPlaybackAudioToWatch(
    Uint8List pcm, {
    int sampleRate = 24000,
  }) {
    return _invokeWatchBool('sendPlaybackAudioToWatch', {
      'data': pcm,
      'sampleRate': sampleRate,
      'size': pcm.length,
    });
  }

  @override
  Future<bool> sendPlaybackEofToWatch() {
    return _invokeWatchBool('sendPlaybackEofToWatch', null);
  }

  Future<bool> _invokeWatchBool(String method, Object? arguments) async {
    if (!Platform.isIOS) {
      print('[WatchBridge] Not iOS, $method not available');
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(method, arguments);
      return result ?? false;
    } on PlatformException catch (e) {
      print('[WatchBridge] $method failed: ${e.message}');
      return false;
    }
  }

  void dispose() {
    _messageController.close();
    _audioStartController.close();
    _audioController.close();
    _eofController.close();
  }
}

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bg_ble_client.dart';
import 'bg_socket_client.dart';

class BleBackgroundService {
  /// Start the background service (called from onStart entry point)
  static Future<void> startBackgroundService(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // ============================================================================
    // 1. INITIALIZATION
    // ============================================================================
    
    final bleClient = BleClient();
    final socketClient = SocketClient();
    const defaultSocketUrl = 'ws://192.168.0.44:8002';
    
    await socketClient.connect(defaultSocketUrl);
    
    // ============================================================================
    // 2. BLE CONFIGURATION
    // ============================================================================
    
    int packetCount = 0;
    
    bleClient.onConnectionStateChanged = (state) {
      debugPrint("[BLE BG] Connection state: ${state.name}");
      service.invoke('ble.status', {'status': state.name});
    };
    
    bleClient.onAudioPacketReceived = (data) {
      packetCount++;
      debugPrint("[BLE BG] Packet $packetCount: ${data.length} bytes");
      service.invoke('ble.packet', {
        'count': packetCount,
        'size': data.length,
      });
      
      // Forward packet to socket server with index (will queue if not connected)
      socketClient.sendPacket(data, index: packetCount);
      // Send ACK back to the device
      bleClient.send(Uint8List.fromList([0x41, 0x43, 0x4B])); // "ACK" in ASCII
    };
    
    bleClient.onError = (error) {
      debugPrint("[BLE BG] Error: $error");
      service.invoke('ble.error', {'error': error});
    };
    
    await bleClient.initialize();
    
    // ============================================================================
    // 3. SOCKET CONFIGURATION
    // ============================================================================
    
    // Forward packets from server to BLE
    socketClient.onPacketFromServer = (packet) => bleClient.send(packet);
    
    // ============================================================================
    // 4. SERVICE EVENT HANDLERS
    // ============================================================================
    
    // BLE control events
    service.on('ble.start').listen((event) async {
      await bleClient.scanAndConnect();
    });
    
    service.on('ble.stop').listen((event) async {
      await bleClient.disconnect();
    });
    
    // Socket control events
    service.on('socket.connect').listen((event) async {
      final url = event?['url'] ?? defaultSocketUrl;
      await socketClient.connect(url);
    });
    
    service.on('socket.disconnect').listen((event) async {
      await socketClient.disconnect();
    });
    
    // Service lifecycle events
    service.on('stop').listen((event) async {
      await bleClient.disconnect();
      await socketClient.disconnect();
      service.stopSelf();
    });
    
    // ============================================================================
    // 5. BACKGROUND MAINTENANCE
    // ============================================================================
    
    Timer.periodic(const Duration(seconds: 60), (_) {
      debugPrint("[BLE BG] background tick");
    });
    
    // ============================================================================
    // 6. STARTUP
    // ============================================================================
    
    await bleClient.scanAndConnect();
  }

  late FlutterBackgroundService _service;
  bool _isInitialized = false;

  final StreamController<String> _statusController = StreamController<String>.broadcast();
  final StreamController<int> _packetSizeController = StreamController<int>.broadcast();
  final StreamController<int> _packetCountController = StreamController<int>.broadcast();
  final StreamController<int> _queueSizeController = StreamController<int>.broadcast();


  Stream<String> get statusStream => _statusController.stream;
  Stream<int> get packetSizeStream => _packetSizeController.stream;
  Stream<int> get packetCountStream => _packetCountController.stream;
  Stream<int> get queueSizeStream => _queueSizeController.stream;

  Future<void> init({
    required Future<void> Function(ServiceInstance) onStart,
    required Future<bool> Function(ServiceInstance) onIosBackground,
  }) async {
    if (_isInitialized) return;
    _service = FlutterBackgroundService();

    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: true,
        onStart: onStart,
        isForegroundMode: true,
        autoStartOnBoot: true,
      ),
    );

    _isInitialized = true;
  }

  Future<void> start() async {
    await _service.startService();

    _service.on('ble.status').listen((event) {
      final status = event?['status'] ?? 'unknown';
      _statusController.add(status);
    });

    _service.on('ble.packet').listen((event) {
      final count = event?['count'] ?? 0;
      final size = event?['size'] ?? 0;
      _packetCountController.add(count);
      _packetSizeController.add(size);
    });

    _service.on('ble.error').listen((event) {
      final error = event?['error'] ?? 'Unknown error';
      _statusController.add('error: $error');
    });

    _service.on('socket.queueSize').listen((event) {
      final count = event?['count'] ?? 0;
      _queueSizeController.add(count);
    });
  }

  void startBle() {
    _service.invoke('ble.start');
  }

  void stopBle() {
    _service.invoke('ble.stop');
  }

  void stopService() {
    _service.invoke('stop');
  }

  void connectSocket(String url) {
    _service.invoke('socket.connect', {'url': url});
  }

  void disconnectSocket() {
    _service.invoke('socket.disconnect');
  }


  void dispose() {
    _statusController.close();
    _packetSizeController.close();
    _packetCountController.close();
    _queueSizeController.close();
  }
}

/// Riverpod provider for BleBackgroundService
final bleBackgroundServiceProvider = Provider<BleBackgroundService>((ref) {
  return BleBackgroundService();
});

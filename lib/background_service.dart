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
      bleClient.sendAudio(Uint8List.fromList([0x41, 0x43, 0x4B])); // "ACK" in ASCII
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
    socketClient.onPacketFromServer = (packet) => bleClient.sendAudio(packet);
    
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
    
    // Unified BLE command handler
    service.on('ble.command').listen((event) async {
      final command = event?['command'] as String?;
      final data = event?['data'];
      
      try {
        switch (command) {
          case 'writeHaptic':
            final effectId = data?['effectId'] as int? ?? 16;
            final success = await bleClient.writeHaptic(effectId);
            service.invoke('ble.command.result', {'command': command, 'success': success});
            break;
          case 'readRTC':
            final rtcData = await bleClient.readRTC();
            service.invoke('ble.command.result', {
              'command': command,
              'success': rtcData != null,
              'data': rtcData?.toList(),
            });
            break;
          case 'writeRTC':
            final rtcBytes = data?['data'] as List<int>?;
            if (rtcBytes == null) {
              service.invoke('ble.command.result', {'command': command, 'success': false});
              return;
            }
            final success = await bleClient.writeRTC(Uint8List.fromList(rtcBytes));
            service.invoke('ble.command.result', {'command': command, 'success': success});
            break;
          case 'readDeviceName':
            final name = await bleClient.readDeviceName();
            service.invoke('ble.command.result', {
              'command': command,
              'success': name != null,
              'data': name,
            });
            break;
          case 'writeDeviceName':
            final name = data?['name'] as String?;
            if (name == null) {
              service.invoke('ble.command.result', {'command': command, 'success': false});
              return;
            }
            final success = await bleClient.writeDeviceName(name);
            service.invoke('ble.command.result', {'command': command, 'success': success});
            break;
          case 'writeFileRx':
            final fileRxBytes = data?['data'] as List<int>?;
            if (fileRxBytes == null) {
              service.invoke('ble.command.result', {'command': command, 'success': false});
              return;
            }
            final success = await bleClient.writeFileRx(Uint8List.fromList(fileRxBytes));
            service.invoke('ble.command.result', {'command': command, 'success': success});
            break;
          case 'readFileCtrl':
            final fileCtrlData = await bleClient.readFileCtrl();
            service.invoke('ble.command.result', {
              'command': command,
              'success': fileCtrlData != null,
              'data': fileCtrlData?.toList(),
            });
            break;
          case 'writeFileCtrl':
            final fileCtrlBytes = data?['data'] as List<int>?;
            if (fileCtrlBytes == null) {
              service.invoke('ble.command.result', {'command': command, 'success': false});
              return;
            }
            final success = await bleClient.writeFileCtrl(Uint8List.fromList(fileCtrlBytes));
            service.invoke('ble.command.result', {'command': command, 'success': success});
            break;
          default:
            service.invoke('ble.command.result', {'command': command, 'success': false, 'error': 'Unknown command'});
        }
      } catch (e) {
        service.invoke('ble.command.result', {'command': command, 'success': false, 'error': e.toString()});
      }
    });
    
    // File TX stream handler - separate channel for streaming data
    bleClient.onFileTxDataReceived = (data) {
      service.invoke('ble.fileTx.data', {'data': data.toList()});
    };
    
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
  final StreamController<Uint8List> _fileTxDataController = StreamController<Uint8List>.broadcast();


  Stream<String> get statusStream => _statusController.stream;
  Stream<Uint8List> get fileTxStream => _fileTxDataController.stream;

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

    _service.on('ble.error').listen((event) {
      final error = event?['error'] ?? 'Unknown error';
      _statusController.add('error: $error');
    });

    _service.on('ble.fileTx.data').listen((event) {
      final data = event?['data'] as List<int>?;
      if (data != null) {
        _fileTxDataController.add(Uint8List.fromList(data));
      }
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

  /// Write haptic effect
  Future<bool> writeHaptic(int effectId) async {
    final completer = Completer<bool>();
    late StreamSubscription subscription;
    
    subscription = _service.on('ble.command.result').listen((event) {
      if (event?['command'] == 'writeHaptic') {
        completer.complete(event?['success'] ?? false);
        subscription.cancel();
      }
    });
    
    _service.invoke('ble.command', {'command': 'writeHaptic', 'data': {'effectId': effectId}});
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      subscription.cancel();
      return false;
    });
  }

  /// Read RTC time
  Future<Uint8List?> readRTC() async {
    final completer = Completer<Uint8List?>();
    late StreamSubscription subscription;
    
    subscription = _service.on('ble.command.result').listen((event) {
      if (event?['command'] == 'readRTC') {
        final data = event?['data'] as List<int>?;
        completer.complete(data != null ? Uint8List.fromList(data) : null);
        subscription.cancel();
      }
    });
    
    _service.invoke('ble.command', {'command': 'readRTC'});
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      subscription.cancel();
      return null;
    });
  }

  /// Write RTC time
  Future<bool> writeRTC(Uint8List data) async {
    final completer = Completer<bool>();
    late StreamSubscription subscription;
    
    subscription = _service.on('ble.command.result').listen((event) {
      if (event?['command'] == 'writeRTC') {
        completer.complete(event?['success'] ?? false);
        subscription.cancel();
      }
    });
    
    _service.invoke('ble.command', {'command': 'writeRTC', 'data': {'data': data.toList()}});
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      subscription.cancel();
      return false;
    });
  }

  /// Read device name
  Future<String?> readDeviceName() async {
    final completer = Completer<String?>();
    late StreamSubscription subscription;
    
    subscription = _service.on('ble.command.result').listen((event) {
      if (event?['command'] == 'readDeviceName') {
        completer.complete(event?['data'] as String?);
        subscription.cancel();
      }
    });
    
    _service.invoke('ble.command', {'command': 'readDeviceName'});
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      subscription.cancel();
      return null;
    });
  }

  /// Write device name
  Future<bool> writeDeviceName(String name) async {
    final completer = Completer<bool>();
    late StreamSubscription subscription;
    
    subscription = _service.on('ble.command.result').listen((event) {
      if (event?['command'] == 'writeDeviceName') {
        completer.complete(event?['success'] ?? false);
        subscription.cancel();
      }
    });
    
    _service.invoke('ble.command', {'command': 'writeDeviceName', 'data': {'name': name}});
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      subscription.cancel();
      return false;
    });
  }

  /// Write file RX data
  Future<bool> writeFileRx(Uint8List data) async {
    final completer = Completer<bool>();
    late StreamSubscription subscription;
    
    subscription = _service.on('ble.command.result').listen((event) {
      if (event?['command'] == 'writeFileRx') {
        completer.complete(event?['success'] ?? false);
        subscription.cancel();
      }
    });
    
    _service.invoke('ble.command', {'command': 'writeFileRx', 'data': {'data': data.toList()}});
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      subscription.cancel();
      return false;
    });
  }

  /// Read file control
  Future<Uint8List?> readFileCtrl() async {
    final completer = Completer<Uint8List?>();
    late StreamSubscription subscription;
    
    subscription = _service.on('ble.command.result').listen((event) {
      if (event?['command'] == 'readFileCtrl') {
        final data = event?['data'] as List<int>?;
        completer.complete(data != null ? Uint8List.fromList(data) : null);
        subscription.cancel();
      }
    });
    
    _service.invoke('ble.command', {'command': 'readFileCtrl'});
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      subscription.cancel();
      return null;
    });
  }

  /// Write file control
  Future<bool> writeFileCtrl(Uint8List data) async {
    final completer = Completer<bool>();
    late StreamSubscription subscription;
    
    subscription = _service.on('ble.command.result').listen((event) {
      if (event?['command'] == 'writeFileCtrl') {
        completer.complete(event?['success'] ?? false);
        subscription.cancel();
      }
    });
    
    _service.invoke('ble.command', {'command': 'writeFileCtrl', 'data': {'data': data.toList()}});
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      subscription.cancel();
      return false;
    });
  }

  void dispose() {
    _statusController.close();
    _fileTxDataController.close();
  }
}

/// Riverpod provider for BleBackgroundService
final bleBackgroundServiceProvider = Provider<BleBackgroundService>((ref) {
  return BleBackgroundService();
});

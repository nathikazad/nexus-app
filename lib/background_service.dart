import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bg_ble_client.dart' show BleClient, BleConnectionState;
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
      final requestId = event?['requestId'] as int?;
      final data = event?['data'];
      
      // Helper to send response with request ID
      void sendResult(Map<String, dynamic> result) {
        result['command'] = command;
        if (requestId != null) {
          result['requestId'] = requestId;
        }
        service.invoke('ble.command.result', result);
      }
      
      try {
        switch (command) {
          case 'writeHaptic':
            final effectId = data?['effectId'] as int? ?? 16;
            final success = await bleClient.writeHaptic(effectId);
            sendResult({'success': success});
            break;
          case 'readBattery':
            print('background service: Reading battery data');
            final batteryData = await bleClient.readBattery();
            sendResult({
              'success': batteryData != null,
              'data': batteryData?.toList(),
            });
            break;
          case 'readRTC':
            final rtcData = await bleClient.readRTC();
            sendResult({
              'success': rtcData != null,
              'data': rtcData?.toList(),
            });
            break;
          case 'writeRTC':
            final rtcBytes = data?['data'] as List<int>?;
            if (rtcBytes == null) {
              sendResult({'success': false});
              return;
            }
            final success = await bleClient.writeRTC(Uint8List.fromList(rtcBytes));
            sendResult({'success': success});
            break;
          case 'readDeviceName':
            final name = await bleClient.readDeviceName();
            sendResult({
              'success': name != null,
              'data': name,
            });
            break;
          case 'writeDeviceName':
            final name = data?['name'] as String?;
            if (name == null) {
              sendResult({'success': false});
              return;
            }
            final success = await bleClient.writeDeviceName(name);
            sendResult({'success': success});
            break;
          case 'writeFileRx':
            final fileRxBytes = data?['data'] as List<int>?;
            if (fileRxBytes == null) {
              sendResult({'success': false});
              return;
            }
            final success = await bleClient.writeFileRx(Uint8List.fromList(fileRxBytes));
            sendResult({'success': success});
            break;
          case 'readFileCtrl':
            final fileCtrlData = await bleClient.readFileCtrl();
            sendResult({
              'success': fileCtrlData != null,
              'data': fileCtrlData?.toList(),
            });
            break;
          case 'writeFileCtrl':
            final fileCtrlBytes = data?['data'] as List<int>?;
            if (fileCtrlBytes == null) {
              sendResult({'success': false});
              return;
            }
            final success = await bleClient.writeFileCtrl(Uint8List.fromList(fileCtrlBytes));
            sendResult({'success': success});
            break;
          default:
            sendResult({'success': false, 'error': 'Unknown command'});
        }
      } catch (e) {
        sendResult({'success': false, 'error': e.toString()});
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
  int _requestIdCounter = 0;
  StreamSubscription? _commandResultSubscription;
  final Map<int, Completer<Map<String, dynamic>?>> _pendingRequests = {};

  final StreamController<BleConnectionState> _statusController = StreamController<BleConnectionState>.broadcast();
  final StreamController<Uint8List> _fileTxDataController = StreamController<Uint8List>.broadcast();


  Stream<BleConnectionState> get statusStream => _statusController.stream;
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
      final statusStr = event?['status'] as String? ?? 'scanning';
      try {
        final status = BleConnectionState.values.firstWhere(
          (state) => state.name == statusStr,
          orElse: () => BleConnectionState.scanning,
        );
        _statusController.add(status);
      } catch (e) {
        // Fallback to scanning if parsing fails
        _statusController.add(BleConnectionState.scanning);
      }
    });

    _service.on('ble.error').listen((event) {
      final error = event?['error'] ?? 'Unknown error';
      debugPrint("[BLE BG] Error: $error");
      // Don't add error to status stream, keep current state
    });

    _service.on('ble.fileTx.data').listen((event) {
      final data = event?['data'] as List<int>?;
      if (data != null) {
        _fileTxDataController.add(Uint8List.fromList(data));
      }
    });

    // Set up single shared subscription for command results
    _commandResultSubscription?.cancel();
    _commandResultSubscription = _service.on('ble.command.result').listen((event) {
      final requestId = event?['requestId'] as int?;
      if (requestId != null && _pendingRequests.containsKey(requestId)) {
        final completer = _pendingRequests.remove(requestId);
        completer?.complete(event);
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

  /// Generic command sender with unique request IDs
  Future<T?> _sendCommand<T>({
    required String command,
    Map<String, dynamic>? data,
    required T? Function(Map<String, dynamic>?) responseParser,
    T? Function()? timeoutValue,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final requestId = ++_requestIdCounter;
    final completer = Completer<Map<String, dynamic>?>();
    
    // Register pending request BEFORE sending command to avoid race condition
    _pendingRequests[requestId] = completer;
    
    final commandData = <String, dynamic>{
      'command': command,
      'requestId': requestId,
    };
    if (data != null) {
      commandData['data'] = data;
    }
    
    // Send command after subscription is ready
    _service.invoke('ble.command', commandData);
    
    try {
      final event = await completer.future.timeout(timeout, onTimeout: () {
        _pendingRequests.remove(requestId);
        return null;
      });
      
      if (event == null) {
        return timeoutValue?.call();
      }
      
      // Verify command matches (safety check)
      final eventCommand = event['command'] as String?;
      if (eventCommand != command) {
        debugPrint('[BLE BG] Command mismatch: expected $command, got $eventCommand');
        return timeoutValue?.call();
      }
      
      return responseParser(event);
    } catch (e) {
      _pendingRequests.remove(requestId);
      debugPrint('[BLE BG] Error in _sendCommand: $e');
      return timeoutValue?.call();
    }
  }

  /// Write haptic effect
  Future<bool> writeHaptic(int effectId) async {
    return await _sendCommand<bool>(
      command: 'writeHaptic',
      data: {'effectId': effectId},
      responseParser: (event) => event?['success'] as bool? ?? false,
      timeoutValue: () => false,
    ) ?? false;
  }

  /// Read battery data
  Future<Uint8List?> readBattery() async {
    return await _sendCommand<Uint8List>(
      command: 'readBattery',
      responseParser: (event) {
        print('background service: Read battery data result: $event');
        final dataList = event?['data'];
        if (dataList is List) {
          return Uint8List.fromList(List<int>.from(dataList));
        }
        return null;
      },
      timeoutValue: () => null,
    );
  }

  /// Read RTC time
  Future<Uint8List?> readRTC() async {
    return await _sendCommand<Uint8List>(
      command: 'readRTC',
      responseParser: (event) {
        final dataList = event?['data'];
        if (dataList is List) {
          return Uint8List.fromList(List<int>.from(dataList));
        }
        return null;
      },
      timeoutValue: () => null,
    );
  }

  /// Write RTC time
  Future<bool> writeRTC(Uint8List data) async {
    debugPrint('background service: Writing RTC time: ${data.toString()}');
    return await _sendCommand<bool>(
      command: 'writeRTC',
      data: {'data': data.toList()},
      responseParser: (event) => event?['success'] as bool? ?? false,
      timeoutValue: () => false,
    ) ?? false;
  }

  /// Read device name
  Future<String?> readDeviceName() async {
    return await _sendCommand<String>(
      command: 'readDeviceName',
      responseParser: (event) => event?['data'] as String?,
      timeoutValue: () => null,
    );
  }

  /// Write device name
  Future<bool> writeDeviceName(String name) async {
    return await _sendCommand<bool>(
      command: 'writeDeviceName',
      data: {'name': name},
      responseParser: (event) => event?['success'] as bool? ?? false,
      timeoutValue: () => false,
    ) ?? false;
  }

  /// Write file RX data
  Future<bool> writeFileRx(Uint8List data) async {
    return await _sendCommand<bool>(
      command: 'writeFileRx',
      data: {'data': data.toList()},
      responseParser: (event) => event?['success'] as bool? ?? false,
      timeoutValue: () => false,
    ) ?? false;
  }

  /// Read file control
  Future<Uint8List?> readFileCtrl() async {
    return await _sendCommand<Uint8List>(
      command: 'readFileCtrl',
      responseParser: (event) {
        final dataList = event?['data'];
        if (dataList is List) {
          return Uint8List.fromList(List<int>.from(dataList));
        }
        return null;
      },
      timeoutValue: () => null,
    );
  }

  /// Write file control
  Future<bool> writeFileCtrl(Uint8List data) async {
    return await _sendCommand<bool>(
      command: 'writeFileCtrl',
      data: {'data': data.toList()},
      responseParser: (event) => event?['success'] as bool? ?? false,
      timeoutValue: () => false,
    ) ?? false;
  }

  void dispose() {
    _commandResultSubscription?.cancel();
    _pendingRequests.clear();
    _statusController.close();
    _fileTxDataController.close();
  }
}

/// Riverpod provider for BleBackgroundService
final bleBackgroundServiceProvider = Provider<BleBackgroundService>((ref) {
  return BleBackgroundService();
});

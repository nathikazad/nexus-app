import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEService {
  static final BLEService _instance = BLEService._internal();
  
  /// Singleton instance getter
  static BLEService get instance => _instance;
  
  factory BLEService() => _instance;
  BLEService._internal();

  // Protocol constants
  static const String deviceName = "ESP32_Audio";
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String txCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8"; // ESP32 -> Client (NOTIFY)
  static const String rxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a9"; // Client -> ESP32 (WRITE)
  
  // Signal constants
  static const int signalEof = 0x0000;
  static const int signalPause = 0xFFFE;
  static const int signalResume = 0xFFFD;
  static const int signalAudioPacket = 0x0001;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription? _notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  
  StreamController<Uint8List>? _opusPacketController;
  StreamController<void>? _eofController;
  
  bool _isConnected = false;
  bool _isScanning = false;
  bool _paused = false;

  Stream<Uint8List>? get opusPacketStream => _opusPacketController?.stream;
  Stream<void>? get eofStream => _eofController?.stream;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  
  int getMTU() {
    // Get MTU size (minus 3 bytes for ATT overhead)
    // Fallback to conservative MTU if not available
    try {
      if (_device != null && _isConnected) {
        // flutter_blue_plus doesn't expose MTU directly, use conservative default
        // Typical BLE MTU is 23 bytes default, but can be negotiated up to 517
        // Conservative payload: 185 - 3 = 182 bytes (matches Python fallback)
        return 182;
      }
    } catch (e) {
      debugPrint('Error getting MTU: $e');
    }
    return 182; // Fallback to conservative MTU
  }
  bool get isPaused => _paused;

  Future<bool> initialize() async {
    try {
      // Check if Bluetooth is available
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint('Bluetooth not supported');
        return false;
      }

      // Initialize controllers
      _opusPacketController = StreamController<Uint8List>.broadcast();
      _eofController = StreamController<void>.broadcast();

      
      _scanAndAutoConnectLoop();

      return true;
    } catch (e) {
      debugPrint('Error initializing BLE service: $e');
      return false;
    }
  }

  Future<void> _scanAndAutoConnectLoop() async {
    while (!_isConnected) {
      debugPrint('Starting scan for ESP32 device...');
      final success = await scanAndConnect();
      
      if (success) {
        debugPrint('Successfully connected to device');
        break;
      } else {
        debugPrint('Device not found, will retry in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<bool> scanAndConnect() async {
    if (_isConnected) {
      debugPrint('Already connected');
      return true;
    }

    try {
      _isScanning = true;
      debugPrint('Scanning indefinitely for service UUID $serviceUuid...');

      // Convert service UUID string to Guid for filtering
      final serviceGuid = Guid(serviceUuid);

      // Start scanning indefinitely (no timeout) with service UUID filter
      // This filters at the platform level for better performance
      await FlutterBluePlus.startScan(
        withServices: [serviceGuid],
      );
      
      // Listen for scan results - results are already filtered by service UUID
      StreamSubscription<List<ScanResult>>? scanSubscription;
      
      final completer = Completer<bool>();
      
      scanSubscription = FlutterBluePlus.scanResults.listen(
        (List<ScanResult> results) {
          for (ScanResult result in results) {
            final name = result.device.platformName.isNotEmpty 
                ? result.device.platformName 
                : result.device.advName;
            
            // Device already matched by service UUID via withServices filter
            // All results here have the matching service UUID
            debugPrint('Found device with service UUID: $name at ${result.device.remoteId}');
            scanSubscription?.cancel();
            FlutterBluePlus.stopScan();
            _isScanning = false;
            
            _device = result.device;
            _connectToDevice().then((success) {
              if (!completer.isCompleted) {
                completer.complete(success);
              }
            }).catchError((error) {
              if (!completer.isCompleted) {
                completer.completeError(error);
              }
            });
            return;
          }
        },
        onError: (error) {
          debugPrint('Scan error: $error');
          // Don't complete on error - keep scanning
          // Only complete if explicitly cancelled or device found
        },
      );

      return await completer.future;
    } catch (e) {
      _isScanning = false;
      debugPrint('Error scanning: $e');
      await FlutterBluePlus.stopScan();
      return false;
    }
  }

  Future<bool> _connectToDevice() async {
    if (_device == null) {
      return false;
    }

    try {
      debugPrint('Connecting to device...');
      
      // Connect to device
      await _device!.connect(timeout: const Duration(seconds: 15));
      _isConnected = true;
      debugPrint('Connected!');

      // Discover services
      List<BluetoothService> services = await _device!.discoverServices();
      debugPrint('Discovered ${services.length} services');

      // Find the service and characteristics
      BluetoothService? targetService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        debugPrint('Service not found: $serviceUuid');
        await disconnect();
        return false;
      }

      // Find TX characteristic (NOTIFY)
      for (BluetoothCharacteristic char in targetService.characteristics) {
        if (char.uuid.toString().toLowerCase() == txCharacteristicUuid.toLowerCase()) {
          _txCharacteristic = char;
          debugPrint('Found TX characteristic');
        } else if (char.uuid.toString().toLowerCase() == rxCharacteristicUuid.toLowerCase()) {
          _rxCharacteristic = char;
          debugPrint('Found RX characteristic');
        }
      }

      if (_txCharacteristic == null) {
        debugPrint('TX characteristic not found');
        await disconnect();
        return false;
      }

      // Subscribe to notifications
      await _txCharacteristic!.setNotifyValue(true);
      _notificationSubscription = _txCharacteristic!.lastValueStream.listen(
        _handleNotification,
        onError: (error) {
          debugPrint('Notification error: $error');
        },
      );

      debugPrint('Subscribed to notifications');
      
      // Listen for disconnection
      _connectionSubscription = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('Device disconnected');
          _isConnected = false;
          _notificationSubscription?.cancel();
          _notificationSubscription = null;
          // Restart scanning on disconnect
          _scanAndAutoConnectLoop();
        } else if (state == BluetoothConnectionState.connected) {
          _isConnected = true;
        }
      });

      return true;
    } catch (e) {
      debugPrint('Error connecting: $e');
      _isConnected = false;
      return false;
    }
  }

  void _handleNotification(List<int> data) {
    if (data.isEmpty) return;

    try {
      Uint8List bytes = Uint8List.fromList(data);
      int offset = 0;

      // Parse multi-frame packets
      while (offset + 2 <= bytes.length) {
        // Read identifier (2 bytes, little-endian)
        int identifier = bytes[offset] | (bytes[offset + 1] << 8);
        offset += 2;

        // Handle flow control signals
        if (identifier == signalPause) {
          debugPrint('[FLOW] Received PAUSE signal (0xFFFE) - pausing transmission');
          _paused = true;
          debugPrint('[FLOW] Pause state: $_paused');
          continue;
        }
        if (identifier == signalResume) {
          debugPrint('[FLOW] Received RESUME signal (0xFFFD) - resuming transmission');
          _paused = false;
          debugPrint('[FLOW] Pause state: $_paused');
          continue;
        }

        // Handle EOF
        if (identifier == signalEof) {
          debugPrint('[UPLOAD] Received EOF');
          _eofController?.add(null);
          continue;
        }

        // Handle audio packet
        if (identifier == signalAudioPacket) {
          debugPrint('[UPLOAD] Received AUDIO PACKET');
          // Read packet size (2 bytes, little-endian)
          if (offset + 2 > bytes.length) {
            debugPrint('[WARNING] Incomplete packet size at offset $offset');
            break;
          }
          
          int packetSize = bytes[offset] | (bytes[offset + 1] << 8);
          offset += 2;

          // Check if we have complete packet
          if (offset + packetSize > bytes.length) {
            debugPrint('[WARNING] Incomplete packet at offset $offset');
            break;
          }

          // Extract Opus data
          Uint8List opusData = bytes.sublist(offset, offset + packetSize);
          offset += packetSize;

          // Emit Opus packet
          _opusPacketController?.add(opusData);
        } else {
          debugPrint('[WARNING] Unknown packet identifier: 0x${identifier.toRadixString(16).padLeft(4, '0')}');
          // Try to recover by skipping to next potential packet
          if (offset + 2 <= bytes.length) {
            offset += 2;
          } else {
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error handling notification: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      _isScanning = false;
      _paused = false; // Reset pause state on disconnect
      await FlutterBluePlus.stopScan();
      
      _notificationSubscription?.cancel();
      _notificationSubscription = null;
      
      _connectionSubscription?.cancel();
      _connectionSubscription = null;

      if (_txCharacteristic != null) {
        try {
          await _txCharacteristic!.setNotifyValue(false);
        } catch (e) {
          debugPrint('Error unsubscribing: $e');
        }
        _txCharacteristic = null;
      }

      if (_device != null && _isConnected) {
        await _device!.disconnect();
        _isConnected = false;
      }

      _device = null;
      debugPrint('Disconnected');
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  Future<void> waitIfPaused() async {
    ///Wait if paused (for flow control)"""
    if (_paused) {
      debugPrint('[FLOW] Waiting while paused...');
      int waitCount = 0;
      const int timeoutMs = 5000; // 5 second timeout
      const int timeoutTicks = timeoutMs ~/ 10; // Number of 10ms ticks
      
      while (_paused) {
        await Future.delayed(const Duration(milliseconds: 10));
        waitCount++;
        
        if (waitCount % 100 == 0) {
          debugPrint('[FLOW] Still waiting... (waited ${waitCount * 10}ms)');
        }
        
        // Timeout after 5 seconds - auto-resume
        if (waitCount >= timeoutTicks) {
          debugPrint('[FLOW] Timeout after ${timeoutMs}ms, auto-resuming transmission');
          _paused = false;
          break;
        }
      }
      
      if (!_paused) {
        debugPrint('[FLOW] Resumed, continuing transmission');
      }
    }
  }

  Future<void> sendPacket(Uint8List packet) async {
    if (_rxCharacteristic == null || !_isConnected) {
      debugPrint('[SEND] Cannot send packet: not connected or RX characteristic not available');
      return;
    }

    // Wait if paused (flow control)
    if (_paused) {
      debugPrint('[SEND] Packet queued, waiting for resume (packet size: ${packet.length} bytes)');
    }
    await waitIfPaused();

    try {
      debugPrint('[SEND] Sending packet: ${packet.length} bytes');
      await _rxCharacteristic!.write(packet, withoutResponse: true);
      debugPrint('[SEND] Packet sent successfully');
    } catch (e) {
      debugPrint('[SEND] Error sending packet: $e');
      rethrow;
    }
  }

  Future<void> sendBatch(Uint8List batch) async {
    if (_rxCharacteristic == null || !_isConnected) {
      debugPrint('[SEND] Cannot send batch: not connected or RX characteristic not available');
      return;
    }

    if (batch.isEmpty) {
      return;
    }

    // Wait if paused (flow control)
    await waitIfPaused();

    try {
      debugPrint('[SEND] Sending batch: ${batch.length} bytes');
      await _rxCharacteristic!.write(batch, withoutResponse: true);
      // debugPrint('[SEND] Batch sent successfully');
    } catch (e) {
      debugPrint('[SEND] Error sending batch: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _opusPacketController?.close();
    await _eofController?.close();
    _opusPacketController = null;
    _eofController = null;
  }
}


import 'dart:async';
import 'dart:collection';
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
  static const int signalEof = 0xFFFC;
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
  
  // Packet queue and sender
  final Queue<Uint8List> _packetQueue = Queue<Uint8List>();
  Uint8List _currentBatch = Uint8List(0);
  bool _senderRunning = false;
  Timer? _senderTimer;
  
  bool _isConnected = false;
  bool _isScanning = false;
  bool _paused = false;
  int _currentMtu = 23; // Default BLE MTU (will be updated from callback)

  Stream<Uint8List>? get opusPacketStream => _opusPacketController?.stream;
  Stream<void>? get eofStream => _eofController?.stream;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  
  int getMTU() {
    // Get MTU size (minus 3 bytes for ATT overhead)
    // Returns the current MTU value updated from the callback
    if (_isConnected && _currentMtu > 0) {
      return _currentMtu - 3; // Subtract ATT overhead
    }
    return 20; // Fallback: default BLE MTU (23) - 3 = 20 bytes payload
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

      // Start packet sender
      _startPacketSender();
      
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
      
      // Request larger MTU (iOS may cap at 185, Android supports up to 517)
      try {
        final requestedMtu = await _device!.requestMtu(512);
        debugPrint('Requested MTU: $requestedMtu bytes');
      } catch (e) {
        debugPrint('Error requesting MTU: $e');
      }
      
      // Get and print initial MTU size
      try {
        final mtu = await _device!.mtu.first;
        _currentMtu = mtu;
        debugPrint('MTU size: $mtu bytes');
      } catch (e) {
        debugPrint('Error getting MTU: $e');
      }
      
      // Listen for MTU updates
      _device!.mtu.listen((mtu) {
        _currentMtu = mtu;
        debugPrint('MTU updated: $mtu bytes');
      });
      
      // Listen for disconnection
      _connectionSubscription = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('Device disconnected');
          _isConnected = false;
          _notificationSubscription?.cancel();
          _notificationSubscription = null;
      // Clear queue and batch on disconnect
      _packetQueue.clear();
      _currentBatch = Uint8List(0);
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
      _packetQueue.clear(); // Clear queue on disconnect
      _currentBatch = Uint8List(0); // Clear batch on disconnect
      _currentMtu = 23; // Reset MTU to default on disconnect
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

  /// Enqueue a packet to be sent. Packets are batched up to MTU size before being queued.
  void enqueuePacket(Uint8List packet) {
    if (packet.isEmpty) {
      return;
    }

    final mtu = getMTU();

    // If adding this packet would exceed MTU and we have a batch, enqueue current batch
    if (_currentBatch.isNotEmpty && _currentBatch.length + packet.length > mtu) {
      _packetQueue.add(_currentBatch);
      debugPrint('[BATCH] Enqueued batch: ${_currentBatch.length} bytes (queue size: ${_packetQueue.length})');
      _currentBatch = Uint8List(0);
    }

    // Add packet to current batch
    if (_currentBatch.isEmpty) {
      _currentBatch = Uint8List.fromList(packet);
    } else {
      final newBatch = Uint8List(_currentBatch.length + packet.length);
      newBatch.setRange(0, _currentBatch.length, _currentBatch);
      newBatch.setRange(_currentBatch.length, _currentBatch.length + packet.length, packet);
      _currentBatch = newBatch;
    }
  }

  /// Enqueue an EOF packet. It will be sent after all queued audio packets.
  /// Flushes any pending batch first.
  void enqueueEOF() {
    // Flush any pending batch
    if (_currentBatch.isNotEmpty) {
      _packetQueue.add(_currentBatch);
      debugPrint('[BATCH] Enqueued final batch: ${_currentBatch.length} bytes (queue size: ${_packetQueue.length})');
      _currentBatch = Uint8List(0);
    }

    // Create and enqueue EOF packet
    const int signalEof = 0xFFFC;
    Uint8List eofPacket = Uint8List(2);
    eofPacket[0] = signalEof & 0xFF;
    eofPacket[1] = (signalEof >> 8) & 0xFF;
    _packetQueue.add(eofPacket);
    debugPrint('[QUEUE] Enqueued EOF packet (queue size: ${_packetQueue.length})');
  }

  /// Check if a packet is an EOF packet
  bool _isEOFPacket(Uint8List packet) {
    if (packet.length != 2) {
      return false;
    }
    final identifier = packet[0] | (packet[1] << 8);
    return identifier == signalEof;
  }

  /// Start the background packet sender that processes the queue
  void _startPacketSender() {
    if (_senderRunning) {
      return;
    }
    _senderRunning = true;
    _senderTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      _processQueue();
    });
    debugPrint('[SENDER] Started background packet sender');
  }

  /// Stop the background packet sender
  void _stopPacketSender() {
    _senderRunning = false;
    _senderTimer?.cancel();
    _senderTimer = null;
    debugPrint('[SENDER] Stopped background packet sender');
  }

  /// Process the packet queue - sends ready-to-send batches
  Future<void> _processQueue() async {
    if (!_isConnected || _rxCharacteristic == null || _paused || _packetQueue.isEmpty) {
      return;
    }

    try {
      // Process one batch at a time (batches are already constructed)
      while (_packetQueue.isNotEmpty && !_paused) {
        final batch = _packetQueue.first;
        
        // Check if this is an EOF packet
        if (_isEOFPacket(batch)) {
          // Send EOF packet immediately (not batched)
          _packetQueue.removeFirst();
          await _sendPacket(batch);
          debugPrint('[SEND] Sent EOF packet');
          break; // EOF is always the last packet
        }
        
        // Send the batch (already batched up to MTU)
        _packetQueue.removeFirst();
        await _sendBatch(batch);
        await Future.delayed(const Duration(milliseconds: 5));
      }
    } catch (e) {
      debugPrint('[SENDER] Error processing queue: $e');
    }
  }

  /// Internal method to send a batch to the BLE characteristic
  Future<void> _sendBatch(Uint8List batch) async {
    if (_rxCharacteristic == null || !_isConnected || batch.isEmpty) {
      return;
    }

    try {
      debugPrint('[SEND] Sending batch: ${batch.length} bytes');
      await _rxCharacteristic!.write(batch, withoutResponse: true);
    } catch (e) {
      debugPrint('[SEND] Error sending batch: $e');
      rethrow;
    }
  }

  /// Internal method to send a single packet (for EOF signals)
  Future<void> _sendPacket(Uint8List packet) async {
    if (_rxCharacteristic == null || !_isConnected) {
      debugPrint('[SEND] Cannot send packet: not connected or RX characteristic not available');
      return;
    }

    try {
      debugPrint('[SEND] Sending packet: ${packet.length} bytes');
      await _rxCharacteristic!.write(packet, withoutResponse: true);
    } catch (e) {
      debugPrint('[SEND] Error sending packet: $e');
      rethrow;
    }
  }


  Future<void> dispose() async {
    _stopPacketSender();
    _packetQueue.clear();
    _currentBatch = Uint8List(0);
    await disconnect();
    await _opusPacketController?.close();
    await _eofController?.close();
    _opusPacketController = null;
    _eofController = null;
  }
}


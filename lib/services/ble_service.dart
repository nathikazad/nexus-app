import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../util/ble_queue.dart';
import '../util/ble_audio_transport.dart';

class BLEService {
  static final BLEService _instance = BLEService._internal();
  
  /// Singleton instance getter
  static BLEService get instance => _instance;
  
  factory BLEService() => _instance;
  BLEService._internal();

  // Protocol constants
  static const String defaultDeviceName = "ESP32_Audio";
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String audioTxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8"; // ESP32 -> Client (NOTIFY)
  static const String audioRxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a9"; // Client -> ESP32 (WRITE)
  static const String batteryCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26aa"; // Battery (READ)
  static const String rtcCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ab"; // RTC (READ/WRITE)
  static const String hapticCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ac"; // Haptic (WRITE)
  static const String deviceNameCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ad"; // Device Name (READ/WRITE)

  BluetoothDevice? _device;
  BLEAudioTransport? _audioTransport;
  BluetoothCharacteristic? _batteryCharacteristic;
  BluetoothCharacteristic? _rtcCharacteristic;
  BluetoothCharacteristic? _hapticCharacteristic;
  BluetoothCharacteristic? _deviceNameCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  
  StreamController<Uint8List>? _opusPacketController;
  StreamController<void>? _eofController;
  StreamController<bool>? _connectionStateController;
  
  // Packet queue and sender
  PacketQueue? _packetQueue;
  
  bool _isConnected = false;
  bool _isScanning = false;
  bool _isConnecting = false; // Track if connection loop is running
  int _currentMtu = 23; // Default BLE MTU (will be updated from callback)

  Stream<Uint8List>? get opusPacketStream => _opusPacketController?.stream;
  Stream<void>? get eofStream => _eofController?.stream;
  Stream<bool>? get connectionStateStream => _connectionStateController?.stream;
  BluetoothCharacteristic? get batteryCharacteristic => _batteryCharacteristic;
  BluetoothCharacteristic? get rtcCharacteristic => _rtcCharacteristic;
  BluetoothCharacteristic? get hapticCharacteristic => _hapticCharacteristic;
  BluetoothCharacteristic? get deviceNameCharacteristic => _deviceNameCharacteristic;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  BluetoothDevice? get currentDevice => _device;
  
  /// Get formatted device name (Nexus-XXXXX format)
  String? get deviceName {
    if (_device == null) return null;
    final name = _device!.platformName.isNotEmpty 
        ? _device!.platformName 
        : _device!.advName;
    // If name starts with "Nexus-", return it as-is, otherwise format from MAC
    if (name.startsWith('Nexus-')) {
      return name;
    }
    // Extract last 5 chars of MAC address
    final macStr = _device!.remoteId.toString();
    // MAC format: "XX:XX:XX:XX:XX:XX" or similar, extract last 5 hex chars
    final macParts = macStr.replaceAll(':', '').replaceAll('-', '').toUpperCase();
    if (macParts.length >= 5) {
      final last5 = macParts.substring(macParts.length - 5);
      return 'Nexus-$last5';
    }
    return name;
  }
  
  int getMTU() {
    // Get MTU size (minus 3 bytes for ATT overhead)
    // Returns the current MTU value updated from the callback
    if (_isConnected && _currentMtu > 0) {
      return _currentMtu - 3; // Subtract ATT overhead
    }
    return 20; // Fallback: default BLE MTU (23) - 3 = 20 bytes payload
  }
  bool get isPaused => _audioTransport?.isPaused ?? false;

  Future<bool> initialize() async {
    try {
      // Configure FlutterBluePlus for background operation
      await FlutterBluePlus.setOptions(
        restoreState: true,  // Enable state restoration
      );
      
      // Check if Bluetooth is available
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint('Bluetooth not supported');
        return false;
      }

      // Initialize controllers
      _opusPacketController = StreamController<Uint8List>.broadcast();
      _eofController = StreamController<void>.broadcast();
      _connectionStateController = StreamController<bool>.broadcast();
      
      // Emit initial connection state
      _connectionStateController?.add(_isConnected);

      // Initialize audio transport
      _audioTransport = BLEAudioTransport(
        onOpusPacket: (packet) {
          _opusPacketController?.add(packet);
        },
        onEof: () {
          _eofController?.add(null);
        },
        onPauseStateChanged: (_) {
          // Pause state is managed by transport, no action needed here
        },
      );

      // Initialize packet queue
      _packetQueue = PacketQueue(
        isConnected: () => _isConnected,
        getMTU: getMTU,
        getRxCharacteristic: () => _audioTransport?.audioRxCharacteristic,
        isPaused: () => _audioTransport?.isPaused ?? false,
      );
      
      // Start packet sender
      _packetQueue?.start();
      
      _scanAndAutoConnectLoop();

      return true;
    } catch (e) {
      debugPrint('Error initializing BLE service: $e');
      return false;
    }
  }

  Future<void> _scanAndAutoConnectLoop() async {
    // Prevent multiple loops from running
    if (_isConnecting) {
      debugPrint('Connection loop already running, skipping...');
      return;
    }
    
    _isConnecting = true;
    while (!_isConnected && _isConnecting) {
      debugPrint('Starting scan for ESP32 device...');
      final success = await scanAndConnect();
      
      if (success) {
        debugPrint('Successfully connected to device');
        _isConnecting = false;
        break;
      } else {
        debugPrint('Device not found, will retry in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    _isConnecting = false;
  }

  /// Scan for devices and return a list of discovered devices
  /// Returns a stream of scan results
  Stream<List<ScanResult>> scanForDevices({Duration? timeout}) async* {
    if (_isScanning) {
      debugPrint('Scan already in progress');
      return;
    }

    try {
      _isScanning = true;
      debugPrint('Scanning for devices with service UUID $serviceUuid...');

      // Stop any existing scan first
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        // Ignore errors if scan wasn't running
      }

      // Convert service UUID string to Guid for filtering
      final serviceGuid = Guid(serviceUuid);

      // Start scanning with service UUID filter
      await FlutterBluePlus.startScan(
        withServices: [serviceGuid],
        timeout: timeout ?? const Duration(seconds: 10),
      );

      // Yield scan results as they come in
      await for (final results in FlutterBluePlus.scanResults) {
        // Filter to only include devices with our service UUID
        final filteredResults = results.where((result) {
          // Results are already filtered by withServices, but double-check
          return true;
        }).toList();
        
        if (filteredResults.isNotEmpty) {
          yield filteredResults;
        }
      }
    } catch (e) {
      debugPrint('Error scanning for devices: $e');
      yield [];
    } finally {
      _isScanning = false;
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        // Ignore errors
      }
    }
  }

  /// Connect to a specific device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (_isConnected && _device?.remoteId == device.remoteId) {
      debugPrint('Already connected to this device');
      return true;
    }

    // Stop auto-connect loop when manually selecting a device
    _isConnecting = false;

    // Disconnect from current device if connected to a different one
    if (_isConnected && _device?.remoteId != device.remoteId) {
      await disconnect();
    }

    _device = device;
    return await _connectToDevice();
  }

  Future<bool> scanAndConnect() async {
    if (_isConnected) {
      debugPrint('Already connected');
      return true;
    }
    
    if (_isConnecting && _isScanning) {
      debugPrint('Connection already in progress');
      return false;
    }

    try {
      _isScanning = true;
      debugPrint('Scanning indefinitely for service UUID $serviceUuid...');

      // Stop any existing scan first
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        // Ignore errors if scan wasn't running
      }

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
      bool deviceFound = false; // Flag to prevent multiple connection attempts
      
      scanSubscription = FlutterBluePlus.scanResults.listen(
        (List<ScanResult> results) {
          if (deviceFound || _isConnected) return; // Prevent duplicate connections
          
          for (ScanResult result in results) {
            if (deviceFound || _isConnected) break;
            
            // Get device name from advertising packet (as set in EEPROM)
            final name = result.advertisementData.advName.isNotEmpty 
                ? result.advertisementData.advName 
                : (result.device.platformName.isNotEmpty 
                ? result.device.platformName 
                    : result.device.advName);
            
            // Device already matched by service UUID via withServices filter
            // All results here have the matching service UUID
            debugPrint('Found device with service UUID: $name at ${result.device.remoteId}');
            deviceFound = true; // Set flag before connecting
            scanSubscription?.cancel();
            FlutterBluePlus.stopScan();
            _isScanning = false;
            
            _device = result.device;
            _connectToDevice().then((success) {
              if (!completer.isCompleted) {
                completer.complete(success);
              }
            }).catchError((error) {
              deviceFound = false; // Reset on error
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
      
      // Connect to device with auto-connect enabled for background operation
      // Note: mtu must be null when autoConnect is true (flutter_blue_plus requirement)
      await _device!.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: true,  // Enable auto-reconnection in background
        mtu: null,  // Required to be null when autoConnect is true
      );
      
      // Wait for connection to be fully established (important with autoConnect)
      await _device!.connectionState.firstWhere(
        (state) => state == BluetoothConnectionState.connected,
        orElse: () => BluetoothConnectionState.disconnected,
      );
      
      _isConnected = true;
      _connectionStateController?.add(true);
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

      // Initialize audio transport with TX/RX characteristics
      if (_audioTransport == null) {
        debugPrint('Audio transport not initialized');
        await disconnect();
        return false;
      }
      
      if (!_audioTransport!.initializeCharacteristics(targetService, audioTxCharacteristicUuid, audioRxCharacteristicUuid)) {
        debugPrint('Failed to initialize audio TX/RX characteristics');
        await disconnect();
        return false;
      }

      // Find battery, RTC, haptic, and device name characteristics
      for (BluetoothCharacteristic char in targetService.characteristics) {
        if (char.uuid.toString().toLowerCase() == batteryCharacteristicUuid.toLowerCase()) {
          _batteryCharacteristic = char;
          debugPrint('Found Battery characteristic');
        } else if (char.uuid.toString().toLowerCase() == rtcCharacteristicUuid.toLowerCase()) {
          _rtcCharacteristic = char;
          debugPrint('Found RTC characteristic');
        } else if (char.uuid.toString().toLowerCase() == hapticCharacteristicUuid.toLowerCase()) {
          _hapticCharacteristic = char;
          debugPrint('Found Haptic characteristic');
        } else if (char.uuid.toString().toLowerCase() == deviceNameCharacteristicUuid.toLowerCase()) {
          _deviceNameCharacteristic = char;
          debugPrint('Found Device Name characteristic');
        }
      }

      // Subscribe to audio TX notifications via transport
      if (!await _audioTransport!.subscribeToNotifications()) {
        debugPrint('Failed to subscribe to audio notifications');
        await disconnect();
        return false;
      }
      
      // Note: Cannot request MTU when autoConnect is enabled (flutter_blue_plus limitation)
      // The device will negotiate MTU automatically, and we'll listen for updates below
      // For background operation, autoConnect takes priority over explicit MTU request
      
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
      
      // Listen for disconnection and restored connections
      _connectionSubscription = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('Device disconnected');
          _isConnected = false;
          _connectionStateController?.add(false);
          _audioTransport?.unsubscribeFromNotifications();
          // Clear queue and batch on disconnect
          _packetQueue?.clear();
          // Restart scanning on disconnect (only if not already connecting)
          if (!_isConnecting) {
            _scanAndAutoConnectLoop();
          }
        } else if (state == BluetoothConnectionState.connected) {
          _isConnected = true;
          _connectionStateController?.add(true);
          _isConnecting = false; // Reset connecting flag when connected
          
          // Check if characteristics need to be reinitialized (e.g., after restore)
          // This handles the case where the OS restores the connection but characteristics aren't set up
          if (_audioTransport?.audioRxCharacteristic == null || 
              _batteryCharacteristic == null) {
            debugPrint('Connection restored, reinitializing characteristics...');
            _reinitializeAfterRestore();
          }
        }
      });

      return true;
    } catch (e) {
      debugPrint('Error connecting: $e');
      _isConnected = false;
      _connectionStateController?.add(false);
      return false;
    }
  }

  /// Reinitialize characteristics after state restoration
  Future<void> _reinitializeAfterRestore() async {
    if (_device == null) {
      return;
    }
    
    try {
      // Wait for connection to be fully established
      await _device!.connectionState.firstWhere(
        (state) => state == BluetoothConnectionState.connected,
        orElse: () => BluetoothConnectionState.disconnected,
      );
      
      if (!_isConnected) {
        _isConnected = true;
        _connectionStateController?.add(true);
      }
      
      debugPrint('Reinitializing characteristics after restore...');
      
      // Rediscover services and characteristics
      List<BluetoothService> services = await _device!.discoverServices();
      debugPrint('Discovered ${services.length} services after restore');

      // Find the service and characteristics
      BluetoothService? targetService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        debugPrint('Service not found after restore: $serviceUuid');
        return;
      }

      // Initialize audio transport with TX/RX characteristics
      if (_audioTransport == null) {
        debugPrint('Audio transport not initialized after restore');
        return;
      }
      
      if (!_audioTransport!.initializeCharacteristics(targetService, audioTxCharacteristicUuid, audioRxCharacteristicUuid)) {
        debugPrint('Failed to initialize audio TX/RX characteristics after restore');
        return;
      }

      // Find battery, RTC, haptic, and device name characteristics
      for (BluetoothCharacteristic char in targetService.characteristics) {
        if (char.uuid.toString().toLowerCase() == batteryCharacteristicUuid.toLowerCase()) {
          _batteryCharacteristic = char;
          debugPrint('Found Battery characteristic after restore');
        } else if (char.uuid.toString().toLowerCase() == rtcCharacteristicUuid.toLowerCase()) {
          _rtcCharacteristic = char;
          debugPrint('Found RTC characteristic after restore');
        } else if (char.uuid.toString().toLowerCase() == hapticCharacteristicUuid.toLowerCase()) {
          _hapticCharacteristic = char;
          debugPrint('Found Haptic characteristic after restore');
        } else if (char.uuid.toString().toLowerCase() == deviceNameCharacteristicUuid.toLowerCase()) {
          _deviceNameCharacteristic = char;
          debugPrint('Found Device Name characteristic after restore');
        }
      }

      // Subscribe to audio TX notifications via transport
      if (!await _audioTransport!.subscribeToNotifications()) {
        debugPrint('Failed to subscribe to audio notifications after restore');
        return;
      }
      
      debugPrint('Successfully reinitialized after restore');
    } catch (e) {
      debugPrint('Error reinitializing after restore: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      _isScanning = false;
      _isConnecting = false; // Reset connecting flag on disconnect
      _audioTransport?.resetPauseState(); // Reset pause state on disconnect
      _packetQueue?.clear(); // Clear queue on disconnect
      _currentMtu = 23; // Reset MTU to default on disconnect
      await FlutterBluePlus.stopScan();
      
      await _audioTransport?.unsubscribeFromNotifications();
      
      _connectionSubscription?.cancel();
      _connectionSubscription = null;
      
      _batteryCharacteristic = null;
      _rtcCharacteristic = null;
      _hapticCharacteristic = null;
      _deviceNameCharacteristic = null;

      if (_device != null && _isConnected) {
        await _device!.disconnect();
        _isConnected = false;
        _connectionStateController?.add(false);
      }

      _device = null;
      debugPrint('Disconnected');
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  /// Enqueue a packet to be sent. Packets are batched up to MTU size before being queued.
  void enqueuePacket(Uint8List packet) {
    _packetQueue?.enqueuePacket(packet);
  }

  /// Enqueue an EOF packet. It will be sent after all queued audio packets.
  /// Flushes any pending batch first.
  void enqueueEOF() {
    _packetQueue?.enqueueEOF();
  }


  Future<void> dispose() async {
    _packetQueue?.dispose();
    await _audioTransport?.dispose();
    await disconnect();
    await _opusPacketController?.close();
    await _eofController?.close();
    await _connectionStateController?.close();
    _opusPacketController = null;
    _eofController = null;
    _connectionStateController = null;
    _packetQueue = null;
    _audioTransport = null;
  }
}


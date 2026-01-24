import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// =============================================================================
// BLE CONSTANTS
// =============================================================================

class BleConstants {
  static const String defaultDeviceName = "Nexus-Audio";
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String audioTxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String audioRxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a9";
}

// =============================================================================
// BLE CONNECTION STATE
// =============================================================================

enum BleConnectionState {
  scanning,
  connecting,
  connected,
}

// =============================================================================
// BLE LISTENER INTERFACE
// =============================================================================

abstract class IBleListener {
  void onConnectionStateChanged(BleConnectionState state);
  void onAudioPacketReceived(Uint8List data);
  void onError(String error);
}

// =============================================================================
// SIMPLE BLE HELPER - Minimal BLE implementation for background socket test
// =============================================================================

class BleClient {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _audioTxCharacteristic;
  BluetoothCharacteristic? _audioRxCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  
  BleConnectionState _state = BleConnectionState.scanning;
  IBleListener? _listener;
  
  bool _isScanning = false;
  int _packetCount = 0;
  
  BleConnectionState get state => _state;
  bool get isConnected => _state == BleConnectionState.connected;
  int get packetCount => _packetCount;
  BluetoothDevice? get device => _device;
  BluetoothCharacteristic? get audioRxCharacteristic => _audioRxCharacteristic;
  
  void setListener(IBleListener listener) {
    _listener = listener;
  }
  
  void _setState(BleConnectionState newState) {
    _state = newState;
    _listener?.onConnectionStateChanged(newState);
  }
  
  void _log(String message) {
    debugPrint("[BLE] $message");
  }
  
  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================
  
  Future<bool> initialize() async {
    try {
      // Configure FlutterBluePlus for background operation
      await FlutterBluePlus.setOptions(restoreState: true);
      
      // Check if Bluetooth is available
      if (await FlutterBluePlus.isSupported == false) {
        _log('Bluetooth not supported');
        _listener?.onError('Bluetooth not supported');
        return false;
      }
      
      _log('BLE initialized');
      return true;
    } catch (e) {
      _log('Error initializing BLE: $e');
      _listener?.onError('Error initializing BLE: $e');
      return false;
    }
  }
  
  // ===========================================================================
  // SCANNING
  // ===========================================================================
  
  Future<void> startScan() async {
    if (_isScanning) {
      _log('Already scanning');
      return;
    }
    
    _setState(BleConnectionState.scanning);
    _isScanning = true;
    _log('Starting scan for Nexus device...');
    
    try {
      // Wait for Bluetooth adapter to be on
      await FlutterBluePlus.adapterState
          .where((val) => val == BluetoothAdapterState.on)
          .first;
      
      // Start scanning with service filter
      final serviceGuid = Guid(BleConstants.serviceUuid);
      
      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) async {
          for (ScanResult result in results) {
            if (result.device.platformName.isNotEmpty) {
              _log('Found device: ${result.device.platformName}');
              
              // Auto-connect to first matching device
              await stopScan();
              _device = result.device;
              await _connectToDevice();
              return;
            }
          }
        },
        onError: (e) {
          _log('Scan error: $e');
          _listener?.onError('Scan error: $e');
        },
      );
      
      // Start the scan indefinitely (no timeout - will scan until device found or manually stopped)
      await FlutterBluePlus.startScan(
        withServices: [serviceGuid],
      );
      
      // Note: Scan will continue indefinitely until:
      // 1. A device is found (handled in scan listener above)
      // 2. stopScan() is called manually
      // The scan subscription will remain active until one of these happens
    } catch (e) {
      _log('Scan error: $e');
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
      _listener?.onError('Scan error: $e');
      // Auto-retry: restart scanning
      await scanAndConnect();
    }
  }
  
  Future<void> stopScan() async {
    if (_isScanning) {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      // State remains scanning (not connected, ready to scan again)
      _log('Scan stopped');
    }
  }
  
  // ===========================================================================
  // CONNECTION
  // ===========================================================================
  
  Future<bool> _connectToDevice() async {
    if (_device == null) {
      _log('No device to connect to');
      return false;
    }
    
    _setState(BleConnectionState.connecting);
    _log('Connecting to ${_device!.platformName}...');
    
    try {
      // Connect to device
      await _device!.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: true,
        mtu: null,
        license: License.free,
      );
      
      // Wait for connected state
      await _device!.connectionState
          .firstWhere((state) => state == BluetoothConnectionState.connected)
          .timeout(const Duration(seconds: 15));
      
      _log('Connected to ${_device!.platformName}');
      
      // Discover services
      final services = await _device!.discoverServices();
      _log('Discovered ${services.length} services');
      
      // Find our service
      BluetoothService? targetService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == BleConstants.serviceUuid.toLowerCase()) {
          targetService = service;
          break;
        }
      }
      
      if (targetService == null) {
        _log('Service not found: ${BleConstants.serviceUuid}');
        await disconnect();
        return false;
      }
      
      // Find audio characteristics
      for (BluetoothCharacteristic char in targetService.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        if (uuid == BleConstants.audioTxCharacteristicUuid.toLowerCase()) {
          _audioTxCharacteristic = char;
          _log('Found Audio TX characteristic');
        } else if (uuid == BleConstants.audioRxCharacteristicUuid.toLowerCase()) {
          _audioRxCharacteristic = char;
          _log('Found Audio RX characteristic');
        }
      }
      
      // Subscribe to audio notifications
      await _subscribeToAudioNotifications();
      
      // Listen for connection state changes
      _connectionSubscription = _device!.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          _log('Device disconnected');
          await _handleDisconnection();
        }
      });
      
      _setState(BleConnectionState.connected);
      return true;
    } catch (e) {
      _log('Connection error: $e');
      _listener?.onError('Connection error: $e');
      // Auto-retry: restart scanning
      await scanAndConnect();
      return false;
    }
  }
  
  Future<void> _subscribeToAudioNotifications() async {
    if (_audioTxCharacteristic == null) {
      _log('Cannot subscribe: Audio TX characteristic not found');
      return;
    }
    
    try {
      await _audioTxCharacteristic!.setNotifyValue(true);
      
      _notificationSubscription = _audioTxCharacteristic!.lastValueStream.listen(
        (value) {
          if (value.isEmpty) return;
          
          final data = Uint8List.fromList(value);
          _packetCount++;
          
          // Parse and forward audio data
          _handleAudioNotification(data);
        },
        onError: (error) {
          _log('Notification error: $error');
          _listener?.onError('Notification error: $error');
        },
      );
      
      _log('Subscribed to audio notifications');
    } catch (e) {
      _log('Error subscribing to notifications: $e');
      _listener?.onError('Error subscribing: $e');
    }
  }
  
  void _handleAudioNotification(Uint8List data) {
    // Simply forward the raw data to the listener
    // The listener (socket) will handle the data
    _listener?.onAudioPacketReceived(data);
  }
  
  Future<void> _handleDisconnection() async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _audioTxCharacteristic = null;
    _audioRxCharacteristic = null;
    
    // Auto-reconnect: restart scanning to find and connect to device again
    _log('Device disconnected, restarting scan to reconnect...');
    await scanAndConnect();
  }
  
  // ===========================================================================
  // PUBLIC METHODS
  // ===========================================================================
  
  /// Scan and connect to Nexus device
  Future<bool> scanAndConnect() async {
    // First check for already connected devices (iOS background mode)
    final alreadyConnected = await _checkForAlreadyConnectedDevice();
    if (alreadyConnected) {
      return true;
    }
    
    // Otherwise, start scanning
    await startScan();
    return isConnected;
  }
  
  /// Check for already connected devices (important for iOS background mode)
  Future<bool> _checkForAlreadyConnectedDevice() async {
    try {
      _log('Checking for already-connected devices...');
      
      // Wait for Bluetooth adapter to be on first
      await FlutterBluePlus.adapterState
          .where((val) => val == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 5));
      
      final serviceGuid = Guid(BleConstants.serviceUuid);
      final connectedDevices = await FlutterBluePlus.systemDevices([serviceGuid]);
      
      for (final device in connectedDevices) {
        _log('Found system-connected device: ${device.platformName}');
        _device = device;
        final success = await _connectToDevice();
        if (success) {
          return true;
        }
      }
    } catch (e) {
      _log('Error checking for connected devices: $e');
    }
    return false;
  }
  
  /// Disconnect from device
  Future<void> disconnect() async {
    try {
      await stopScan();
      await _notificationSubscription?.cancel();
      _notificationSubscription = null;
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;
      
      if (_device != null && isConnected) {
        await _device!.disconnect();
      }
      
      _device = null;
      _audioTxCharacteristic = null;
      _audioRxCharacteristic = null;
      _packetCount = 0;
      _log('Disconnected');
      // Auto-reconnect: restart scanning
      await scanAndConnect();
    } catch (e) {
      _log('Error disconnecting: $e');
    }
  }
  
  /// Send data to the device (via Audio RX characteristic)
  Future<void> send(Uint8List data) async {
    if (!isConnected || _audioRxCharacteristic == null) {
      _log('Cannot send: not connected');
      return;
    }
    
    try {
      await _audioRxCharacteristic!.write(data, withoutResponse: true);
    } catch (e) {
      _log('Send error: $e');
      rethrow;
    }
  }
  
  /// Get effective MTU (MTU - 3 bytes for ATT overhead)
  Future<int> getEffectiveMtu() async {
    if (_device == null) {
      return 20; // Default: 23 - 3
    }
    
    try {
      final mtu = await _device!.mtu.first.timeout(const Duration(seconds: 2));
      return mtu - 3; // Subtract ATT overhead
    } catch (e) {
      _log('Could not get MTU, using default: $e');
      return 20; // Default: 23 - 3
    }
  }
  
  /// Send a batch of data
  Future<void> sendBatch(Uint8List batch) async {
    await send(batch);
  }
  
  /// Send EOF signal (0xFFFC)
  Future<void> sendEof() async {
    const int signalEof = 0xFFFC;
    final eofPacket = Uint8List(2);
    eofPacket[0] = signalEof & 0xFF;
    eofPacket[1] = (signalEof >> 8) & 0xFF;
    await send(eofPacket);
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    _listener = null;
  }
}


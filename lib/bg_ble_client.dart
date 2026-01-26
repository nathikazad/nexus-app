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
  static const String batteryCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26aa";
  static const String hapticCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ac";
  static const String rtcCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ab";
  static const String deviceNameCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ad";
  static const String fileTxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ae";
  static const String fileRxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26af";
  static const String fileCtrlCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26b0";
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
// SIMPLE BLE HELPER - Minimal BLE implementation for background socket test
// =============================================================================

class BleClient {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _audioTxCharacteristic;
  BluetoothCharacteristic? _audioRxCharacteristic;
  BluetoothCharacteristic? _batteryCharacteristic;
  BluetoothCharacteristic? _hapticCharacteristic;
  BluetoothCharacteristic? _rtcCharacteristic;
  BluetoothCharacteristic? _deviceNameCharacteristic;
  BluetoothCharacteristic? _fileTxCharacteristic;
  BluetoothCharacteristic? _fileRxCharacteristic;
  BluetoothCharacteristic? _fileCtrlCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _fileTxNotificationSubscription;
  
  BleConnectionState _state = BleConnectionState.scanning;
  
  bool _isScanning = false;
  
  BleConnectionState get state => _state;
  bool get isConnected => _state == BleConnectionState.connected;
  BluetoothDevice? get device => _device;
  BluetoothCharacteristic? get audioRxCharacteristic => _audioRxCharacteristic;
  
  // Direct callback properties for event handling
  void Function(BleConnectionState)? onConnectionStateChanged;
  void Function(Uint8List)? onAudioPacketReceived;
  void Function(Uint8List)? onFileTxDataReceived;
  void Function(String)? onError;
  
  void _setState(BleConnectionState newState) {
    _state = newState;
    onConnectionStateChanged?.call(newState);
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
        onError?.call('Bluetooth not supported');
        return false;
      }
      
      _log('BLE initialized');
      return true;
    } catch (e) {
      _log('Error initializing BLE: $e');
      onError?.call('Error initializing BLE: $e');
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
          onError?.call('Scan error: $e');
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
      onError?.call('Scan error: $e');
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
      
      // Find characteristics
      for (BluetoothCharacteristic char in targetService.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        if (uuid == BleConstants.audioTxCharacteristicUuid.toLowerCase()) {
          _audioTxCharacteristic = char;
          _log('Found Audio TX characteristic');
        } else if (uuid == BleConstants.audioRxCharacteristicUuid.toLowerCase()) {
          _audioRxCharacteristic = char;
          _log('Found Audio RX characteristic');
        } else if (uuid == BleConstants.batteryCharacteristicUuid.toLowerCase()) {
          _batteryCharacteristic = char;
          _log('Found Battery characteristic');
        } else if (uuid == BleConstants.hapticCharacteristicUuid.toLowerCase()) {
          _hapticCharacteristic = char;
          _log('Found Haptic characteristic');
        } else if (uuid == BleConstants.rtcCharacteristicUuid.toLowerCase()) {
          _rtcCharacteristic = char;
          _log('Found RTC characteristic');
        } else if (uuid == BleConstants.deviceNameCharacteristicUuid.toLowerCase()) {
          _deviceNameCharacteristic = char;
          _log('Found Device Name characteristic');
        } else if (uuid == BleConstants.fileTxCharacteristicUuid.toLowerCase()) {
          _fileTxCharacteristic = char;
          _log('Found File TX characteristic');
        } else if (uuid == BleConstants.fileRxCharacteristicUuid.toLowerCase()) {
          _fileRxCharacteristic = char;
          _log('Found File RX characteristic');
        } else if (uuid == BleConstants.fileCtrlCharacteristicUuid.toLowerCase()) {
          _fileCtrlCharacteristic = char;
          _log('Found File CTRL characteristic');
        }
      }
      
      // Subscribe to audio notifications
      await _subscribeToAudioNotifications();
      
      // Subscribe to file TX notifications
      await _subscribeToFileTxNotifications();
      
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
      onError?.call('Connection error: $e');
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
          
          // Parse and forward audio data
          _handleAudioNotification(data);
        },
        onError: (error) {
          _log('Notification error: $error');
          onError?.call('Notification error: $error');
        },
      );
      
      _log('Subscribed to audio notifications');
    } catch (e) {
      _log('Error subscribing to notifications: $e');
      onError?.call('Error subscribing: $e');
    }
  }
  
  void _handleAudioNotification(Uint8List data) {
    // Forward the raw data via callback
    onAudioPacketReceived?.call(data);
  }
  
  Future<void> _subscribeToFileTxNotifications() async {
    if (_fileTxCharacteristic == null) {
      _log('Cannot subscribe: File TX characteristic not found');
      return;
    }
    
    try {
      await _fileTxCharacteristic!.setNotifyValue(true);
      
      _fileTxNotificationSubscription = _fileTxCharacteristic!.lastValueStream.listen(
        (value) {
          if (value.isEmpty) return;
          final data = Uint8List.fromList(value);
          // Forward file TX data via callback
          onFileTxDataReceived?.call(data);
        },
        onError: (error) {
          _log('File TX notification error: $error');
          onError?.call('File TX notification error: $error');
        },
      );
      
      _log('Subscribed to file TX notifications');
    } catch (e) {
      _log('Error subscribing to file TX notifications: $e');
      onError?.call('Error subscribing to file TX: $e');
    }
  }
  
  Future<void> _handleDisconnection() async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    await _fileTxNotificationSubscription?.cancel();
    _fileTxNotificationSubscription = null;
    _audioTxCharacteristic = null;
    _audioRxCharacteristic = null;
    _batteryCharacteristic = null;
    _hapticCharacteristic = null;
    _rtcCharacteristic = null;
    _deviceNameCharacteristic = null;
    _fileTxCharacteristic = null;
    _fileRxCharacteristic = null;
    _fileCtrlCharacteristic = null;
    
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
      await _fileTxNotificationSubscription?.cancel();
      _fileTxNotificationSubscription = null;
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;
      
      if (_device != null && isConnected) {
        await _device!.disconnect();
      }
      
      _device = null;
      _audioTxCharacteristic = null;
      _audioRxCharacteristic = null;
      _batteryCharacteristic = null;
      _hapticCharacteristic = null;
      _rtcCharacteristic = null;
      _deviceNameCharacteristic = null;
      _fileTxCharacteristic = null;
      _fileRxCharacteristic = null;
      _fileCtrlCharacteristic = null;
      _log('Disconnected');
      // Auto-reconnect: restart scanning
      await scanAndConnect();
    } catch (e) {
      _log('Error disconnecting: $e');
    }
  }
  
  /// Send data to the device (via Audio RX characteristic)
  Future<void> sendAudio(Uint8List data) async {
    print('Sending data: ${data.length} bytes');
    if (!isConnected || _audioRxCharacteristic == null) {
      _log('Cannot send: not connected');
      return;
    }
    
    try {
      print('Writing data: ${data.length} bytes');
      await _audioRxCharacteristic!.write(data, withoutResponse: true);
    } catch (e) {
      _log('Send error: $e');
      rethrow;
    }
  }
  
  /// Read battery data
  Future<Uint8List?> readBattery() async {
    if (!isConnected || _batteryCharacteristic == null) {
      _log('Cannot read battery: not connected');
      return null;
    }
    try {
      final data = await _batteryCharacteristic!.read();
      return Uint8List.fromList(data);
    } catch (e) {
      _log('Error reading battery: $e');
      return null;
    }
  }
  
  /// Write haptic effect
  Future<bool> writeHaptic(int effectId) async {
    if (!isConnected || _hapticCharacteristic == null) {
      _log('Cannot write haptic: not connected');
      return false;
    }
    try {
      await _hapticCharacteristic!.write(Uint8List.fromList([effectId]), withoutResponse: true);
      return true;
    } catch (e) {
      _log('Error writing haptic: $e');
      return false;
    }
  }
  
  /// Read RTC time
  Future<Uint8List?> readRTC() async {
    if (!isConnected || _rtcCharacteristic == null) {
      _log('Cannot read RTC: not connected');
      return null;
    }
    try {
      final data = await _rtcCharacteristic!.read();
      return Uint8List.fromList(data);
    } catch (e) {
      _log('Error reading RTC: $e');
      return null;
    }
  }
  
  /// Write RTC time
  Future<bool> writeRTC(Uint8List data) async {
    if (!isConnected || _rtcCharacteristic == null) {
      _log('Cannot write RTC: not connected');
      return false;
    }
    try {
      print('Writing RTC time: ${data.toString()}');
      await _rtcCharacteristic!.write(data, withoutResponse: false);
      return true;
    } catch (e) {
      _log('Error writing RTC: $e');
      return false;
    }
  }
  
  /// Read device name
  Future<String?> readDeviceName() async {
    if (!isConnected || _deviceNameCharacteristic == null) {
      _log('Cannot read device name: not connected');
      return null;
    }
    try {
      final data = await _deviceNameCharacteristic!.read();
      if (data.isEmpty) return null;
      return String.fromCharCodes(data);
    } catch (e) {
      _log('Error reading device name: $e');
      return null;
    }
  }
  
  /// Write device name
  Future<bool> writeDeviceName(String name) async {
    if (!isConnected || _deviceNameCharacteristic == null) {
      _log('Cannot write device name: not connected');
      return false;
    }
    if (name.length >= 20) {
      _log('Device name too long: ${name.length} (max 19)');
      return false;
    }
    try {
      await _deviceNameCharacteristic!.write(Uint8List.fromList(name.codeUnits), withoutResponse: false);
      return true;
    } catch (e) {
      _log('Error writing device name: $e');
      return false;
    }
  }
  
  /// Write file RX data
  Future<bool> writeFileRx(Uint8List data) async {
    if (!isConnected || _fileRxCharacteristic == null) {
      _log('Cannot write file RX: not connected');
      return false;
    }
    try {
      await _fileRxCharacteristic!.write(data, withoutResponse: true);
      return true;
    } catch (e) {
      _log('Error writing file RX: $e');
      return false;
    }
  }
  
  /// Read file control
  Future<Uint8List?> readFileCtrl() async {
    if (!isConnected || _fileCtrlCharacteristic == null) {
      _log('Cannot read file control: not connected');
      return null;
    }
    try {
      final data = await _fileCtrlCharacteristic!.read();
      return Uint8List.fromList(data);
    } catch (e) {
      _log('Error reading file control: $e');
      return null;
    }
  }
  
  /// Write file control
  Future<bool> writeFileCtrl(Uint8List data) async {
    if (!isConnected || _fileCtrlCharacteristic == null) {
      _log('Cannot write file control: not connected');
      return false;
    }
    try {
      await _fileCtrlCharacteristic!.write(data, withoutResponse: true);
      return true;
    } catch (e) {
      _log('Error writing file control: $e');
      return false;
    }
  }
  
  /// Get effective MTU (MTU - 3 bytes for ATT overhead)
  Future<int> getEffectiveMtu() async {
    if (_device == null) {
      return 20; // Default: 23 - 3
    }
    
    try {
      final mtu = await _device!.mtu.first.timeout(const Duration(seconds: 2));
      print('MTU: $mtu');
      return mtu - 3; // Subtract ATT overhead
    } catch (e) {
      _log('Could not get MTU, using default: $e');
      return 20; // Default: 23 - 3
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    onConnectionStateChanged = null;
    onAudioPacketReceived = null;
    onFileTxDataReceived = null;
    onError = null;
  }
}


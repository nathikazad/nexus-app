import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:nexus_voice_assistant/services/hardware_service/rtc_service.dart';
import 'package:nexus_voice_assistant/services/paired_device_storage.dart';

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
  static const String cameraCmdCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26b1";
  static const String cameraStatusCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26b2";
}

// =============================================================================
// BLE CONNECTION STATE MACHINE
// =============================================================================
//
// State transitions:
//   idle -> scanning (startScan — first-time discovery only)
//   idle -> connecting (reconnect via autoConnect)
//   scanning -> idle (stopScan / error)
//   scanning -> connecting (device found)
//   connecting -> connected (success)
//   connecting -> idle (failure — autoConnect stays registered with OS)
//   connected -> connecting (disconnect + autoConnect reconnect)
//

enum BleConnectionState {
  idle,
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
  BluetoothCharacteristic? _cameraCmdCharacteristic;
  BluetoothCharacteristic? _cameraStatusCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription? _globalConnectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _fileTxNotificationSubscription;
  StreamSubscription<List<int>>? _cameraStatusNotificationSubscription;
  StreamSubscription<List<int>>? _batteryNotificationSubscription;
  
  BleConnectionState _state = BleConnectionState.idle;

  /// When set (or loaded from [PairedDeviceStorage]), only that peripheral is used.
  String? _preferredRemoteId;

  /// Overrides in-memory preference (e.g. from background isolate message).
  void setPreferredRemoteId(String? id) {
    _preferredRemoteId = id;
  }

  /// Reload [PairedDeviceStorage] into [_preferredRemoteId].
  Future<void> reloadPreferredFromStorage() async {
    _preferredRemoteId = await PairedDeviceStorage.getPairedRemoteId();
  }

  bool _matchesPreferred(BluetoothDevice device) {
    final pref = _preferredRemoteId;
    if (pref == null || pref.isEmpty) return false;
    return device.remoteId.str == pref;
  }
  
  BleConnectionState get state => _state;
  bool get isConnected => _state == BleConnectionState.connected;
  BluetoothDevice? get device => _device;
  BluetoothCharacteristic? get audioRxCharacteristic => _audioRxCharacteristic;
  
  // Direct callback properties for event handling
  void Function(BleConnectionState)? onConnectionStateChanged;
  void Function(Uint8List)? onAudioPacketReceived;
  void Function(Uint8List)? onFileTxDataReceived;
  void Function(bool isRecording, int periodSec)? onCameraStatusReceived;
  void Function(Uint8List)? onBatteryReceived;
  void Function(String)? onError;

  /// Curated connection lifecycle lines (scanning, found, connected, disconnected).
  /// Bridged to [LoggingService] on the main isolate via the background service.
  void Function(String message)? onDiagnosticLog;

  void _setState(BleConnectionState newState) {
    _state = newState;
    onConnectionStateChanged?.call(newState);
  }

  void _log(String message) {
    debugPrint("[BLE] $message");
  }

  void _diagnosticLog(String message) {
    _log(message);
    onDiagnosticLog?.call(message);
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
      
      _listenForGlobalConnectionEvents();
      _log('BLE initialized');
      return true;
    } catch (e) {
      _log('Error initializing BLE: $e');
      onError?.call('Error initializing BLE: $e');
      return false;
    }
  }
  
  // ===========================================================================
  // GLOBAL CONNECTION LISTENER
  // ===========================================================================

  void _listenForGlobalConnectionEvents() {
    _globalConnectionSubscription?.cancel();
    _globalConnectionSubscription = FlutterBluePlus.events.onConnectionStateChanged.listen(
      (event) async {
        if (event.connectionState == BluetoothConnectionState.connected) {
          await reloadPreferredFromStorage();
          if (!_matchesPreferred(event.device)) {
            _log('Global connect ignored (not the paired device)');
            return;
          }
          _log('Global event: device connected: ${event.device.platformName}');
          if (_state == BleConnectionState.connected || _state == BleConnectionState.connecting) {
            _log('Already handling a connection, ignoring');
            return;
          }
          _device = event.device;
          await stopScan();
          await _setupConnectedDevice();
        }
      },
    );
  }

  // ===========================================================================
  // SCANNING
  // ===========================================================================
  
  Future<void> startScan() async {
    if (_state == BleConnectionState.scanning) {
      _log('Already scanning');
      return;
    }
    await reloadPreferredFromStorage();
    if (_preferredRemoteId == null || _preferredRemoteId!.isEmpty) {
      _diagnosticLog('Cannot scan: no paired device ID. Select a device in the app first.');
      return;
    }

    _setState(BleConnectionState.scanning);
    _diagnosticLog('Starting scan for paired Nexus device...');
    
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
            if (!_matchesPreferred(result.device)) {
              continue;
            }
            final name = result.device.platformName.isNotEmpty
                ? result.device.platformName
                : result.device.advName;
            if (name.isEmpty) {
              continue;
            }
            _diagnosticLog('Found paired device: $name');
            await stopScan();
            _device = result.device;
            await _connectToDevice();
            return;
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
      _setState(BleConnectionState.idle);
      onError?.call('Scan error: $e');
    }
  }
  
  Future<void> stopScan() async {
    if (_state == BleConnectionState.scanning) {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      await FlutterBluePlus.stopScan();
      _setState(BleConnectionState.idle);
      _log('Scan stopped');
    }
  }
  
  // ===========================================================================
  // CONNECTION
  // ===========================================================================

  void _cancelConnectionSubscription() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  void _clearCharacteristics() {
    _audioTxCharacteristic = null;
    _audioRxCharacteristic = null;
    _batteryCharacteristic = null;
    _hapticCharacteristic = null;
    _rtcCharacteristic = null;
    _deviceNameCharacteristic = null;
    _fileTxCharacteristic = null;
    _fileRxCharacteristic = null;
    _fileCtrlCharacteristic = null;
    _cameraCmdCharacteristic = null;
    _cameraStatusCharacteristic = null;
  }

  /// Attempt a direct connect with a short timeout. Used when the device was
  /// just seen (scan result / user pick) and is expected to be in range now.
  Future<bool> _connectToDevice() async {
    if (_device == null) {
      _log('No device to connect to');
      return false;
    }
    if (_state == BleConnectionState.connecting) {
      _log('Connection already in progress, ignoring');
      return isConnected;
    }
    _setState(BleConnectionState.connecting);
    _log('Connecting to ${_device!.platformName}...');

    try {
      final alreadyConnected = _device!.isConnected;
      if (!alreadyConnected) {
        await _device!.connect(
          timeout: const Duration(seconds: 15),
          autoConnect: true,
          mtu: null,
          license: License.free,
        );

        await _device!.connectionState
            .firstWhere((state) => state == BluetoothConnectionState.connected)
            .timeout(const Duration(seconds: 15));
      }

      return await _setupConnectedDevice();
    } catch (e) {
      _log('Connection error: $e');
      onError?.call('Connection error: $e');
      _setState(BleConnectionState.idle);
      return false;
    }
  }

  /// Register an autoConnect intent and return immediately. The OS will
  /// reconnect when the peripheral is back in range; the global connection
  /// listener calls [_setupConnectedDevice] at that point.
  /// No active scanning — works in iOS background and Low Power Mode.
  Future<void> _reconnectToPairedDevice() async {
    if (_preferredRemoteId == null || _preferredRemoteId!.isEmpty) return;

    if (await _checkForAlreadyConnectedDevice()) return;

    _diagnosticLog('Registering autoConnect for paired device...');
    _setState(BleConnectionState.connecting);

    try {
      _device = BluetoothDevice.fromId(_preferredRemoteId!);
      await _device!.connect(autoConnect: true, license: License.free);
      // autoConnect resolves when actually connected
      await _setupConnectedDevice();
    } catch (e) {
      _log('autoConnect failed: $e');
      _setState(BleConnectionState.idle);
      // The autoConnect intent may still be registered at the native level.
      // The global connection listener is the safety net — don't scan.
    }
  }

  /// Post-connection setup: bonding, service discovery, notification subscriptions.
  /// Called after the device is already connected at the OS level (either from
  /// [_connectToDevice], [_reconnectToPairedDevice], or the global listener).
  Future<bool> _setupConnectedDevice() async {
    if (_device == null) {
      _log('No device for setup');
      return false;
    }

    _setState(BleConnectionState.connecting);
    _diagnosticLog('Connected to ${_device!.platformName}, setting up...');

    try {
      if (Platform.isAndroid) {
        try {
          await _device!.createBond(timeout: 90);
          _log('Bonding complete (Android)');
        } catch (e) {
          _log('createBond (non-fatal): $e');
        }
      }

      final services = await _device!.discoverServices();
      _log('Discovered ${services.length} services');

      BluetoothService? targetService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == BleConstants.serviceUuid.toLowerCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        _log('Service not found: ${BleConstants.serviceUuid}');
        _setState(BleConnectionState.idle);
        await disconnect(intentional: true);
        return false;
      }

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
        } else if (uuid == BleConstants.cameraCmdCharacteristicUuid.toLowerCase()) {
          _cameraCmdCharacteristic = char;
          _log('Found Camera CMD characteristic');
        } else if (uuid == BleConstants.cameraStatusCharacteristicUuid.toLowerCase()) {
          _cameraStatusCharacteristic = char;
          _log('Found Camera Status characteristic');
        }
      }

      if (_rtcCharacteristic != null) {
        try {
          final rtcTime = RTCTime.fromDateTime(DateTime.now());
          await _rtcCharacteristic!.write(rtcTime.toBytes(), withoutResponse: false);
          _log('RTC synced: ${rtcTime.toString()}');
        } catch (e) {
          _log('RTC sync failed (non-fatal): $e');
        }
      }

      await _subscribeToAudioNotifications();
      await _subscribeToFileTxNotifications();
      await _subscribeToCameraStatusNotifications();
      await _subscribeToBatteryNotifications();

      _cancelConnectionSubscription();
      _connectionSubscription = _device!.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          _diagnosticLog('Device disconnected');
          await _handleDisconnection();
        }
      });

      _setState(BleConnectionState.connected);
      await PairedDeviceStorage.setPairedRemoteId(_device!.remoteId.str);
      return true;
    } catch (e) {
      _log('Setup error: $e');
      onError?.call('Setup error: $e');
      _setState(BleConnectionState.idle);
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
      
      _notificationSubscription = _audioTxCharacteristic!.onValueReceived.listen(
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
  
  Future<void> _subscribeToCameraStatusNotifications() async {
    if (_cameraStatusCharacteristic == null) {
      _log('Cannot subscribe: Camera Status characteristic not found');
      return;
    }
    
    try {
      await _cameraStatusCharacteristic!.setNotifyValue(true);
      
      _cameraStatusNotificationSubscription = _cameraStatusCharacteristic!.lastValueStream.listen(
        (value) {
          if (value.isEmpty) return;
          final (isRecording, periodSec) = BleClient.parseCameraStatus(Uint8List.fromList(value));
          onCameraStatusReceived?.call(isRecording, periodSec);
        },
        onError: (error) {
          _log('Camera status notification error: $error');
          onError?.call('Camera status notification error: $error');
        },
      );
      
      _log('Subscribed to camera status notifications');
    } catch (e) {
      _log('Error subscribing to camera status notifications: $e');
      onError?.call('Error subscribing to camera status: $e');
    }
  }

  Future<void> _subscribeToBatteryNotifications() async {
    if (_batteryCharacteristic == null) {
      _log('Cannot subscribe: Battery characteristic not found');
      return;
    }

    try {
      await _batteryCharacteristic!.setNotifyValue(true);

      _batteryNotificationSubscription = _batteryCharacteristic!.lastValueStream.listen(
        (value) {
          if (value.isEmpty) return;
          onBatteryReceived?.call(Uint8List.fromList(value));
        },
        onError: (error) {
          _log('Battery notification error: $error');
          onError?.call('Battery notification error: $error');
        },
      );

      _log('Subscribed to battery notifications');
    } catch (e) {
      _log('Error subscribing to battery notifications: $e');
      onError?.call('Error subscribing to battery: $e');
    }
  }

  Future<void> _handleDisconnection() async {
    _cancelConnectionSubscription();
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    await _fileTxNotificationSubscription?.cancel();
    _fileTxNotificationSubscription = null;
    await _cameraStatusNotificationSubscription?.cancel();
    _cameraStatusNotificationSubscription = null;
    await _batteryNotificationSubscription?.cancel();
    _batteryNotificationSubscription = null;
    _clearCharacteristics();

    await reloadPreferredFromStorage();
    if (_preferredRemoteId != null && _preferredRemoteId!.isNotEmpty) {
      _diagnosticLog('Device disconnected, registering autoConnect...');
      await _reconnectToPairedDevice();
    } else {
      _diagnosticLog('Device disconnected (no paired device id; idle)');
      _setState(BleConnectionState.idle);
    }
  }
  
  // ===========================================================================
  // PUBLIC METHODS
  // ===========================================================================
  
  /// Connect to the saved [PairedDeviceStorage] device.
  ///
  /// Tries a direct connect first (device may be in range). On failure, falls
  /// through to [_reconnectToPairedDevice] which registers an autoConnect intent
  /// with the OS — no active scanning.
  ///
  /// [overrideRemoteId] is used when the caller just persisted the id (e.g. main isolate
  /// wrote SharedPreferences) but this isolate has not yet read it — avoids a race where
  /// [reloadPreferredFromStorage] clears the id set by [setPreferredRemoteId].
  Future<bool> scanAndConnect({String? overrideRemoteId}) async {
    if (overrideRemoteId != null && overrideRemoteId.isNotEmpty) {
      _preferredRemoteId = overrideRemoteId;
    } else {
      await reloadPreferredFromStorage();
    }
    if (_preferredRemoteId == null || _preferredRemoteId!.isEmpty) {
      _diagnosticLog('No paired device ID. Select your Nexus in the hardware screen.');
      return false;
    }

    final alreadyConnected = await _checkForAlreadyConnectedDevice();
    if (alreadyConnected) {
      _diagnosticLog('Already connected to paired device');
      return true;
    }
    _diagnosticLog('Connecting to paired device...');

    try {
      _device = BluetoothDevice.fromId(_preferredRemoteId!);
      final ok = await _connectToDevice();
      if (ok) {
        return true;
      }
    } catch (e) {
      _log('Direct connect from saved id failed: $e');
      _device = null;
    }

    // Device not in range right now — register autoConnect and wait for OS reconnect.
    await _reconnectToPairedDevice();
    return isConnected;
  }
  
  /// Check for already connected devices (important for iOS background mode)
  Future<bool> _checkForAlreadyConnectedDevice() async {
    try {
      if (_preferredRemoteId == null || _preferredRemoteId!.isEmpty) {
        return false;
      }
      _log('Checking for already-connected paired device...');
      
      // Wait for Bluetooth adapter to be on first
      await FlutterBluePlus.adapterState
          .where((val) => val == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 5));
      
      final serviceGuid = Guid(BleConstants.serviceUuid);
      final connectedDevices = await FlutterBluePlus.systemDevices([serviceGuid]);
      
      for (final device in connectedDevices) {
        if (!_matchesPreferred(device)) {
          continue;
        }
        _log('Found system-connected paired device: ${device.platformName}');
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
  
  /// Disconnect from device.
  ///
  /// When [intentional] is true (explicit user/caller action like "stop" or
  /// "forget device"), no automatic reconnection is attempted.
  /// When false (e.g. service teardown that should reconnect), falls through
  /// to [_reconnectToPairedDevice].
  Future<void> disconnect({bool intentional = false}) async {
    try {
      await stopScan();
      _cancelConnectionSubscription();
      await _notificationSubscription?.cancel();
      _notificationSubscription = null;
      await _fileTxNotificationSubscription?.cancel();
      _fileTxNotificationSubscription = null;
      await _cameraStatusNotificationSubscription?.cancel();
      _cameraStatusNotificationSubscription = null;
      await _batteryNotificationSubscription?.cancel();
      _batteryNotificationSubscription = null;

      if (_device != null && isConnected) {
        await _device!.disconnect();
      }

      _device = null;
      _clearCharacteristics();
      _setState(BleConnectionState.idle);
      _log('Disconnected (intentional=$intentional)');

      if (!intentional) {
        await reloadPreferredFromStorage();
        if (_preferredRemoteId != null && _preferredRemoteId!.isNotEmpty) {
          await _reconnectToPairedDevice();
        }
      }
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
  
  /// Read battery raw bytes from GATT (see [parseBatteryStatus]).
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

  /// Firmware v2: 12 bytes — [0..3] battery, [4..9] local wall (sec,min,hour,date,month,year 0–99),
  /// [10..11] timezone offset hours/minutes (signed).
  static ({
    int voltageMv,
    int percent,
    bool charging,
    String? timeIso,
    String? timezone,
  })? parseBatteryStatus(Uint8List data) {
    if (data.length < 4) return null;
    final voltageMv = (data[0] << 8) | data[1];
    final percent = data[2];
    final charging = data[3] != 0;
    String? timeIso;
    String? timezone;
    if (data.length >= 12) {
      final sec = data[4];
      final min = data[5];
      final hour = data[6];
      final date = data[7];
      final month = data[8];
      final year = 2000 + data[9];
      final tzH = data[10] > 127 ? data[10] - 256 : data[10];
      final tzM = data[11] > 127 ? data[11] - 256 : data[11];
      final off = _formatIsoOffset(tzH, tzM);
      timeIso =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${date.toString().padLeft(2, '0')}'
          'T${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
          '$off';
      final sign = tzH >= 0 ? '+' : '-';
      final ah = tzH.abs();
      final am = tzM.abs();
      timezone = 'UTC$sign${ah.toString().padLeft(2, '0')}:${am.toString().padLeft(2, '0')}';
    }
    return (
      voltageMv: voltageMv,
      percent: percent,
      charging: charging,
      timeIso: timeIso,
      timezone: timezone,
    );
  }

  static String _formatIsoOffset(int tzH, int tzM) {
    final sign = tzH >= 0 ? '+' : '-';
    final ah = tzH.abs();
    final am = tzM.abs();
    return '$sign${ah.toString().padLeft(2, '0')}:${am.toString().padLeft(2, '0')}';
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

  /// Cold reboot via camera CMD characteristic (firmware opcode 5).
  /// Same byte sequence as [CameraCommand.powerCycle] in `camera_command.dart`.
  Future<bool> writePowerCycle() async {
    return writeCamera(Uint8List.fromList([5]));
  }

  /// Write to camera CMD characteristic.
  /// [data] is the raw payload (e.g. from [CameraCommand.toBytes]).
  Future<bool> writeCamera(Uint8List data) async {
    if (!isConnected || _cameraCmdCharacteristic == null) {
      _log('Cannot write camera: not connected or characteristic not available');
      return false;
    }
    try {
      await _cameraCmdCharacteristic!.write(data, withoutResponse: true);
      _log('Camera command written: ${data.length} bytes');
      return true;
    } catch (e) {
      _log('Error writing camera: $e');
      return false;
    }
  }

  /// Camera record status: [flags][period_lo][period_hi]
  static (bool isRecording, int periodSec) parseCameraStatus(Uint8List data) {
    if (data.length < 3) return (false, 60);
    final isRecording = (data[0] & 1) != 0;
    final periodSec = data[1] | (data[2] << 8);
    return (isRecording, periodSec.clamp(1, 1000));
  }

  /// Read camera status (is recording, period in seconds).
  Future<(bool isRecording, int periodSec)?> readCameraStatus() async {
    if (!isConnected || _cameraStatusCharacteristic == null) {
      _log('Cannot read camera status: not connected or characteristic not available');
      return null;
    }
    try {
      final data = await _cameraStatusCharacteristic!.read();
      return parseCameraStatus(Uint8List.fromList(data));
    } catch (e) {
      _log('Error reading camera status: $e');
      return null;
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
    await _globalConnectionSubscription?.cancel();
    _globalConnectionSubscription = null;
    await disconnect(intentional: true);
    onConnectionStateChanged = null;
    onAudioPacketReceived = null;
    onFileTxDataReceived = null;
    onError = null;
  }
}


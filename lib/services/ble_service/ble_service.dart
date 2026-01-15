import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_audio_transport.dart';
import 'ble_file_transport.dart';
import 'ble_scanner.dart';
import 'ble_connector.dart';
import '../../util/file_transfer.dart';

class BLEService {
  BLEService();

  // Protocol constants
  static const String defaultDeviceName = "Nexus-Audio";
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String audioTxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8"; // ESP32 -> Client (NOTIFY)
  static const String audioRxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a9"; // Client -> ESP32 (WRITE)
  static const String batteryCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26aa"; // Battery (READ)
  static const String rtcCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ab"; // RTC (READ/WRITE)
  static const String hapticCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ac"; // Haptic (WRITE)
  static const String deviceNameCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ad"; // Device Name (READ/WRITE)
  static const String fileTxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ae"; // File TX (NOTIFY)
  static const String fileRxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26af"; // File RX (WRITE)
  static const String fileCtrlCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26b0"; // File CTRL (READ/WRITE)

  BluetoothDevice? _device;
  BluetoothCharacteristic? _batteryCharacteristic;
  BluetoothCharacteristic? _rtcCharacteristic;
  BluetoothCharacteristic? _hapticCharacteristic;
  BluetoothCharacteristic? _deviceNameCharacteristic;
  BluetoothCharacteristic? _fileTxCharacteristic;
  BluetoothCharacteristic? _fileRxCharacteristic;
  BluetoothCharacteristic? _fileCtrlCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  
  StreamController<bool>? _connectionStateController;
  
  // Audio transport
  final BLEAudioTransport _audioTransport = BLEAudioTransport();
  
  // File transport
  final BLEFileTransport _fileTransport = BLEFileTransport();
  
  bool _isConnected = false;
  bool _isConnecting = false; // Track if connection loop is running
  int _currentMtu = 23; // Default BLE MTU (will be updated from callback)

  Stream<bool>? get connectionStateStream => _connectionStateController?.stream;
  BluetoothCharacteristic? get batteryCharacteristic => _batteryCharacteristic;
  BluetoothCharacteristic? get rtcCharacteristic => _rtcCharacteristic;
  BluetoothCharacteristic? get hapticCharacteristic => _hapticCharacteristic;
  BluetoothCharacteristic? get deviceNameCharacteristic => _deviceNameCharacteristic;
  BluetoothCharacteristic? get fileTxCharacteristic => _fileTxCharacteristic;
  BluetoothCharacteristic? get fileRxCharacteristic => _fileRxCharacteristic;
  BluetoothCharacteristic? get fileCtrlCharacteristic => _fileCtrlCharacteristic;
  bool get isConnected => _isConnected;
  bool get isScanning => BLEScanner.isScanning;
  BluetoothDevice? get currentDevice => _device;
  
  int getMTU() {
    // Get MTU size (minus 3 bytes for ATT overhead)
    // Returns the current MTU value updated from the callback
    if (_isConnected && _currentMtu > 0) {
      return _currentMtu - 3; // Subtract ATT overhead
    }
    return 20; // Fallback: default BLE MTU (23) - 3 = 20 bytes payload
  }

  Future<bool> initialize({
    void Function(Uint8List)? onPcm24ChunkReceived,
    void Function()? onEofReceived,
    Stream<Uint8List>? openAiAudioOutStream,
    void Function(FileEntry)? onFileReceived,
    void Function(List<FileEntry>)? onListFilesReceived,
  }) async {

    if (_connectionStateController != null) {
      return true;
    }
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
      _connectionStateController = StreamController<bool>.broadcast();
      
      // Emit initial connection state
      _connectionStateController?.add(_isConnected);

      // Initialize audio transport with callbacks and dependencies
      _audioTransport.initialize(
        onPcm24Chunk: onPcm24ChunkReceived,
        onEof: onEofReceived,
        openAiAudioOutStream: openAiAudioOutStream,
        isConnected: () => isConnected,
        getMTU: () => getMTU(),
      );

          // Initialize file transport callbacks and dependencies
      _fileTransport.initialize(
        onFileReceived: onFileReceived,
        onListFilesReceived: onListFilesReceived,
        isConnected: () => isConnected,
        getMTU: () => getMTU(),
      );
      _fileTransport.onDataReceived ??= _handleFileData;
        
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
  static Stream<List<ScanResult>> scanForDevices({Duration? timeout}) async* {
    yield* BLEScanner.scanForDevices(
      serviceUuid: serviceUuid,
      timeout: timeout,
    );
  }

  static void stopScan() {
    BLEScanner.stopScan();
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
    
    if (_isConnecting && BLEScanner.isScanning) {
      debugPrint('Connection already in progress');
      return false;
    }

    final device = await BLEScanner.scanForSingleDevice(serviceUuid: serviceUuid);
    if (device == null) {
      return false;
    }

    _device = device;
    return await _connectToDevice();
  }

  Future<bool> _connectToDevice() async {
    if (_device == null) {
      return false;
    }
    final result = await BLEConnector.connectAndSetup(
      device: _device!,
      audioTransport: _audioTransport,
      fileTransport: _fileTransport,
      setBatteryCharacteristic: (char) => _batteryCharacteristic = char,
      setRtcCharacteristic: (char) => _rtcCharacteristic = char,
      setHapticCharacteristic: (char) => _hapticCharacteristic = char,
      setDeviceNameCharacteristic: (char) => _deviceNameCharacteristic = char,
      setFileTxCharacteristic: (char) => _fileTxCharacteristic = char,
      setFileRxCharacteristic: (char) => _fileRxCharacteristic = char,
      setFileCtrlCharacteristic: (char) => _fileCtrlCharacteristic = char,
      setConnected: (connected) {
        _isConnected = connected;
        if (connected) {
          _isConnecting = false;
        }
      },
      updateMtu: (mtu) => _currentMtu = mtu,
      emitConnectionState: (connected) => _connectionStateController?.add(connected),
      onDisconnected: () async {
        await _audioTransport.unsubscribeFromNotifications();
        _audioTransport.resetPauseState();
        if (!_isConnecting) {
          _scanAndAutoConnectLoop();
        }
      },
      shouldReinitialize: () => _batteryCharacteristic == null,
      reinitializeAfterRestore: _reinitializeAfterRestore,
    );

    _connectionSubscription = result.connectionSubscription;
    return result.success;
  }

  /// Reinitialize characteristics after state restoration
  Future<void> _reinitializeAfterRestore() async {
    if (_device == null) {
      return;
    }

    await BLEConnector.reinitializeAfterRestore(
      device: _device!,
      audioTransport: _audioTransport,
      fileTransport: _fileTransport,
      setBatteryCharacteristic: (char) => _batteryCharacteristic = char,
      setRtcCharacteristic: (char) => _rtcCharacteristic = char,
      setHapticCharacteristic: (char) => _hapticCharacteristic = char,
      setDeviceNameCharacteristic: (char) => _deviceNameCharacteristic = char,
      setFileTxCharacteristic: (char) => _fileTxCharacteristic = char,
      setFileRxCharacteristic: (char) => _fileRxCharacteristic = char,
      setFileCtrlCharacteristic: (char) => _fileCtrlCharacteristic = char,
    );
  }
  
  /// Handle file data received from FILE_TX_CHAR
  void _handleFileData(Uint8List data) {
    debugPrint('BLEService: Received file data packet, length ${data.length}');
    // For now, just log. File data handling will be implemented in higher layers.
  }
  
  /// Send file request command (triggers file receive with all logic in BLEFileTransport)
  Future<void> sendFileRequest(String path) async {
    await _fileTransport.requestFile(path);
  }
  
  /// Send list files request command
  Future<void> sendListFilesRequest({String? path}) async {
    await _fileTransport.sendListFilesRequest(path: path);
  }

  /// Enqueue a packet to be sent. Packets are batched up to MTU size before being queued.
  void enqueuePacket(Uint8List packet) {
    _audioTransport.enqueuePacket(packet);
  }

  /// Send EOF to ESP32
  Future<void> sendEOFToEsp32() async {
    await _audioTransport.sendEOFToEsp32();
  }

  Future<void> disconnect() async {
    try {
      _isConnecting = false; // Reset connecting flag on disconnect
      await _audioTransport.unsubscribeFromNotifications();
      _audioTransport.resetPauseState();
      await _fileTransport.unsubscribeFromNotifications();
      _currentMtu = 23; // Reset MTU to default on disconnect
      BLEScanner.stopScan();
      
      _connectionSubscription?.cancel();
      _connectionSubscription = null;
      
      _batteryCharacteristic = null;
      _rtcCharacteristic = null;
      _hapticCharacteristic = null;
      _deviceNameCharacteristic = null;
      _fileTxCharacteristic = null;
      _fileRxCharacteristic = null;
      _fileCtrlCharacteristic = null;

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

  Future<void> dispose() async {
    await _audioTransport.dispose();
    await disconnect();
    await _connectionStateController?.close();
    _connectionStateController = null;
  }
}


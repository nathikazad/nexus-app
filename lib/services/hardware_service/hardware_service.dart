import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../ble_service/ble_service.dart';
import 'battery_service.dart';
import 'rtc_service.dart';
import 'name_service.dart';
import 'haptic_service.dart';
import '../openai_service.dart';
import '../file_transfer_service.dart';

class HardwareService {
  static final HardwareService _instance = HardwareService._internal();
  
  /// Singleton instance getter
  static HardwareService get instance => _instance;
  
  factory HardwareService() => _instance;

  final BLEService _bleService;
  final BatteryService _batteryService;
  final RTCService _rtcService;
  final NameService _nameService;
  final HapticService _hapticService;

  HardwareService._internal()
      : _bleService = _sharedBleService,
        _batteryService = BatteryService(_sharedBleService),
        _rtcService = RTCService(_sharedBleService),
        _nameService = NameService(_sharedBleService),
        _hapticService = HapticService(_sharedBleService);
  
  // Shared BLEService instance for all services
  static final BLEService _sharedBleService = BLEService();
  
  bool _isInitialized = false;

  Stream<BatteryData>? get batteryStream => _batteryService.batteryStream;
  Stream<bool>? get connectionStateStream => _bleService.connectionStateStream;
  bool get isConnected => _bleService.isConnected;
  bool get isInitialized => _isInitialized;

  // Device name getter
  String? get deviceName => _nameService.deviceName;


  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Wait for BLE service to be initialized (this also initializes audio transport)
      await _bleService.initialize(
        onPcm24ChunkReceived: (pcm24Chunk) {
          OpenAIService.instance.sendAudio(pcm24Chunk, queryOrigin.Hardware);
        },
        onEofReceived: () {
          OpenAIService.instance.createResponse();
        },
        openAiAudioOutStream: OpenAIService.instance.hardWareAudioOutStream,
        onFileReceived: (fileEntry) {
          FileTransferService.instance.onFileReceived(fileEntry);
        },
        onListFilesReceived: (fileNameList) {
          debugPrint('hardware service: Received ${fileNameList.length} files from LIST_RESPONSE');
          FileTransferService.instance.onListFilesReceived(fileNameList);
        }
      );
      
      // Initialize battery service
      await _batteryService.initialize();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing HardwareService: $e');
      return false;
    }
  }

  void sendFileRequest(String path) {
    _bleService.sendFileRequest(path);
  }

  void sendListFilesRequest() {
    _bleService.sendListFilesRequest();
  }

  /// Enqueue a packet to be sent. Packets are batched up to MTU size before being queued.
  void enqueueOpusPacket(Uint8List packet) {
        _bleService.enqueuePacket(packet);
  }

  /// Send EOF to ESP32
  Future<void> sendEOAudioToEsp32() async {
    await _bleService.sendEOFToEsp32();
  }

  /// Connect to a specific BLE device
  Future<bool> connect(BluetoothDevice device) async {
    return await _bleService.connectToDevice(device);
  }

  /// Read battery data from device (percentage, voltage, and charging status)
  Future<BatteryData?> readBattery() async {
    return await _batteryService.readBattery();
  }

  /// Read RTC time from device (includes timezone)
  Future<RTCTime?> readRTC() async {
    return await _rtcService.readRTC();
  }

  /// Write RTC time to device
  Future<bool> writeRTC(RTCTime time) async {
    return await _rtcService.writeRTC(time);
  }

  /// Set RTC time from current system time (preserves existing timezone)
  Future<bool> setRTCTimeNow() async {
    return await _rtcService.setRTCTimeNow();
  }

  /// Trigger haptic pulse with specified effect ID
  /// @param effectId Effect ID (0-123, where 0 = stop, 1-123 = predefined effects)
  /// @return true on success, false on failure
  Future<bool> triggerHapticPulse({int effectId = 16}) async {
    return await _hapticService.triggerHapticPulse(effectId: effectId);
  }

  /// Read device name from device
  /// @return Device name string, or null on failure
  Future<String?> readDeviceName() async {
    return await _nameService.readDeviceName();
  }

  /// Write device name to device
  /// @param name Device name to set (max 19 characters)
  /// @return true on success, false on failure
  Future<bool> writeDeviceName(String name) async {
    return await _nameService.writeDeviceName(name);
  }

  Future<void> dispose() async {
    await _batteryService.dispose();
    
    _isInitialized = false;
  }
}


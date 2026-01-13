import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nexus_voice_assistant/services/openai_service.dart';
import '../services/ble_service.dart';
import '../util/ble_audio_transport.dart';
import 'battery_service.dart';
import 'rtc_service.dart';

class HardwareService {
  static final HardwareService _instance = HardwareService._internal();
  
  /// Singleton instance getter
  static HardwareService get instance => _instance;
  
  factory HardwareService() => _instance;

  final BLEService _bleService = BLEService.instance;
  final BatteryService _batteryService;
  final RTCService _rtcService;
  final BLEAudioTransport _audioTransport;

  HardwareService._internal()
      : _batteryService = BatteryService(BLEService.instance),
        _rtcService = RTCService(BLEService.instance),
        _audioTransport = BLEAudioTransport();
  
  bool _isInitialized = false;

  Stream<BatteryData>? get batteryStream => _batteryService.batteryStream;
  bool get isInitialized => _isInitialized;

  // Device name getter
  String? get deviceName {
    final device = _bleService.currentDevice;
    if (device == null) return null;
    final name = device.platformName.isNotEmpty 
        ? device.platformName 
        : device.advName;
    // If name starts with "Nexus-", return it as-is, otherwise format from MAC
    if (name.startsWith('Nexus-')) {
      return name;
    }
    // Extract last 5 chars of MAC address
    final macStr = device.remoteId.toString();
    // MAC format: "XX:XX:XX:XX:XX:XX" or similar, extract last 5 hex chars
    final macParts = macStr.replaceAll(':', '').replaceAll('-', '').toUpperCase();
    if (macParts.length >= 5) {
      final last5 = macParts.substring(macParts.length - 5);
      return 'Nexus-$last5';
    }
    return name;
  }


  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Wait for BLE service to be initialized
      await _bleService.initialize();
      
      // Initialize audio transport with callbacks and dependencies
      _audioTransport.initialize(
        onPcm24Chunk: (pcm24Chunk) {
          OpenAIService.instance.sendAudio(pcm24Chunk, queryOrigin.Hardware);
        },
        onEof: () {
          OpenAIService.instance.createResponse();
        },
        openAiAudioOutStream: OpenAIService.instance.hardWareAudioOutStream,
        isConnected: () => _bleService.isConnected,
        getMTU: () => _bleService.getMTU(),
      );
      
      // Initialize audio processing pipeline (includes packet queue, stream subscriptions, and OpenAI relayer)
      _audioTransport.initializeAudioProcessing();
      
      // Initialize battery service
      await _batteryService.initialize();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing HardwareService: $e');
      return false;
    }
  }


  /// Initialize audio transport characteristics (called from BLEService after connection)
  Future<bool> initializeAudioTransportCharacteristics(BluetoothService service, String audioTxUuid, String audioRxUuid) async {
    if (!await _audioTransport.initializeAudioTransportCharacteristics(service, audioTxUuid, audioRxUuid)) {
      debugPrint('Failed to initialize audio TX/RX characteristics');
      return false;
    }
    
    return true;
  }
  
  /// Disconnect audio transport (unsubscribe from notifications and reset pause state)
  Future<void> disconnectAudioTransport() async {
    await _audioTransport.unsubscribeFromNotifications();
    _audioTransport.resetPauseState();
  }
  
  /// Enqueue a packet to be sent. Packets are batched up to MTU size before being queued.
  void enqueuePacket(Uint8List packet) {
    _audioTransport.enqueuePacket(packet);
      }

  /// Send EOF to ESP32
  Future<void> sendEOFToEsp32() async {
    await _audioTransport.sendEOFToEsp32();
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
  Future<bool> triggerHapticPulse() async {
    final hapticCharacteristic = _bleService.hapticCharacteristic;
    if (!_bleService.isConnected || hapticCharacteristic == null) {
      debugPrint('Cannot trigger haptic pulse: not connected or characteristic not available');
      return false;
    }

 

    try {
      // Write 1-byte effect ID to haptic characteristic
      final data = Uint8List.fromList([16]);
      await hapticCharacteristic.write(data, withoutResponse: true);
      debugPrint('Haptic pulse triggered');
      return true;
    } catch (e) {
      debugPrint('Error triggering haptic pulse: $e');
      return false;
    }
  }

  /// Read device name from device
  /// @return Device name string, or null on failure
  Future<String?> readDeviceName() async {
    final deviceNameCharacteristic = _bleService.deviceNameCharacteristic;
    if (!_bleService.isConnected || deviceNameCharacteristic == null) {
      return null;
    }

    try {
      final data = await deviceNameCharacteristic.read();
      if (data.isNotEmpty) {
        // Convert bytes to string (UTF-8)
        final name = String.fromCharCodes(data);
        debugPrint('Device name read: "$name"');
        return name;
      }
      return null;
    } catch (e) {
      debugPrint('Error reading device name: $e');
      return null;
    }
  }

  /// Write device name to device
  /// @param name Device name to set (max 19 characters)
  /// @return true on success, false on failure
  Future<bool> writeDeviceName(String name) async {
    final deviceNameCharacteristic = _bleService.deviceNameCharacteristic;
    if (!_bleService.isConnected || deviceNameCharacteristic == null) {
      debugPrint('Cannot write device name: not connected or characteristic not available');
      return false;
    }

    // Validate name length (max 19 chars)
    if (name.length >= 20) {
      debugPrint('Device name too long: ${name.length} (max 19)');
      return false;
    }

    try {
      // Convert string to UTF-8 bytes
      final data = Uint8List.fromList(name.codeUnits);
      await deviceNameCharacteristic.write(data, withoutResponse: false);
      debugPrint('Device name written: "$name"');
      return true;
    } catch (e) {
      debugPrint('Error writing device name: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    await _audioTransport.dispose();
    await _batteryService.dispose();
    
    _isInitialized = false;
  }
}


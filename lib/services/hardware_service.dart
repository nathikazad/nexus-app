import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nexus_voice_assistant/services/openai_service.dart';
import 'package:opus_dart/opus_dart.dart';
import '../services/ble_service.dart';
import '../util/audio.dart';

/// RTC time structure
class RTCTime {
  final int seconds;   // 0-59
  final int minutes;   // 0-59
  final int hours;     // 0-23
  final int weekday;  // 1-7 (1=Monday, 7=Sunday)
  final int date;      // 1-31
  final int month;     // 1-12
  final int year;      // 0-99 (offset from 2000)
  final int timezoneHours;   // -12 to +14 (UTC offset hours)
  final int timezoneMinutes; // 0, 30, or 45 (UTC offset minutes)

  RTCTime({
    required this.seconds,
    required this.minutes,
    required this.hours,
    required this.weekday,
    required this.date,
    required this.month,
    required this.year,
    this.timezoneHours = -8,   // Default PST
    this.timezoneMinutes = 0,
  });

  /// Create from 9-byte BLE data (or 7-byte for backward compatibility)
  /// Format: [seconds, minutes, hours, weekday, date, month, year, timezone_hours, timezone_minutes]
  factory RTCTime.fromBytes(Uint8List data) {
    if (data.length < 7) {
      throw ArgumentError('RTC data must be at least 7 bytes');
    }
    int tzHours = -8;   // Default PST
    int tzMinutes = 0;
    
    // If 9 bytes, include timezone
    if (data.length >= 9) {
      tzHours = _signedFromUnsigned(data[7]);
      tzMinutes = _signedFromUnsigned(data[8]);
    }
    
    return RTCTime(
      seconds: data[0],
      minutes: data[1],
      hours: data[2],
      weekday: data[3],
      date: data[4],
      month: data[5],
      year: data[6],
      timezoneHours: tzHours,
      timezoneMinutes: tzMinutes,
    );
  }

  /// Convert signed byte (-128 to 127) from unsigned (0-255)
  static int _signedFromUnsigned(int unsigned) {
    return (unsigned > 127) ? unsigned - 256 : unsigned;
  }

  /// Convert to 9-byte BLE data
  /// Format: [seconds, minutes, hours, weekday, date, month, year, timezone_hours, timezone_minutes]
  Uint8List toBytes() {
    return Uint8List.fromList([
      seconds,
      minutes,
      hours,
      weekday,
      date,
      month,
      year,
      _unsignedFromSigned(timezoneHours),
      _unsignedFromSigned(timezoneMinutes),
    ]);
  }

  /// Convert signed byte (-128 to 127) to unsigned (0-255)
  static int _unsignedFromSigned(int signed) {
    return signed < 0 ? signed + 256 : signed;
  }

  /// Format as string: "2024-01-15 14:30:45"
  @override
  String toString() {
    final fullYear = 2000 + year;
    return '${fullYear.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${date.toString().padLeft(2, '0')} '
        '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Format for display: "MM/DD/YY\nhh:mm am/pm"
  String toDisplayString() {
    final shortYear = year % 100;
    final monthStr = month.toString().padLeft(2, '0');
    final dateStr = date.toString().padLeft(2, '0');
    final yearStr = shortYear.toString().padLeft(2, '0');
    
    // Convert to 12-hour format
    final hour12 = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    final amPm = hours < 12 ? 'am' : 'pm';
    final hourStr = hour12.toString().padLeft(2, '0');
    final minuteStr = minutes.toString().padLeft(2, '0');
    
    return '$monthStr/$dateStr/$yearStr\n$hourStr:$minuteStr $amPm';
  }

  /// Create from DateTime (uses system timezone offset)
  factory RTCTime.fromDateTime(DateTime dateTime, {int? timezoneHours, int? timezoneMinutes}) {
    return RTCTime(
      seconds: dateTime.second,
      minutes: dateTime.minute,
      hours: dateTime.hour,
      weekday: dateTime.weekday, // DateTime.weekday is 1=Monday, 7=Sunday
      date: dateTime.day,
      month: dateTime.month,
      year: dateTime.year - 2000,
      timezoneHours: timezoneHours ?? -8,   // Default PST if not provided
      timezoneMinutes: timezoneMinutes ?? 0,
    );
  }
  
  /// Get timezone string (e.g., "UTC-8:00")
  String getTimezoneString() {
    final sign = timezoneHours >= 0 ? '+' : '';
    return 'UTC$sign$timezoneHours:${timezoneMinutes.toString().padLeft(2, '0')}';
  }

  /// Convert to DateTime
  DateTime toDateTime() {
    return DateTime(2000 + year, month, date, hours, minutes, seconds);
  }
}

class HardwareService {
  static final HardwareService _instance = HardwareService._internal();
  
  /// Singleton instance getter
  static HardwareService get instance => _instance;
  
  factory HardwareService() => _instance;
  HardwareService._internal();

  final BLEService _bleService = BLEService.instance;
  
  StreamOpusDecoder? _streamDecoder;
  OpusToPcm16Transformer? _opusToPcm16Transformer;
  Pcm16ToPcm24Transformer? _pcm16ToPcm24Transformer;
  
  StreamSubscription<Uint8List>? _opusPacketSubscription;
  StreamSubscription<Uint8List>? _pcm24ChunkSubscription;
  StreamSubscription<void>? _eofSubscription;
  StreamSubscription<bool>? _connectionStateSubscription;
  
  Stream<Uint8List>? _pcm24Stream;
  StreamController<int>? _batteryController; // Battery percentage (0-100)
  Timer? _batteryPollTimer;
  
  bool _isInitialized = false;

  Stream<Uint8List>? get pcm24Stream => _pcm24Stream;
  Stream<int>? get batteryStream => _batteryController?.stream;
  bool get isInitialized => _isInitialized;

  int _framesSent = 0;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Wait for BLE service to be initialized
      await _bleService.initialize();
      
      // Create decoder and transformers
      _streamDecoder = AudioProcessor.createDecoder();
      _opusToPcm16Transformer = OpusToPcm16Transformer(_streamDecoder!);
      _pcm16ToPcm24Transformer = Pcm16ToPcm24Transformer();
      
      // Set up the stream pipeline: Opus packets -> PCM16 -> PCM24 chunks
      final opusStream = _bleService.opusPacketStream;
      final eofStream = _bleService.eofStream;
      
      if (opusStream == null) {
        debugPrint('HardwareService: opusPacketStream is null');
        return false;
      }
      
      if (eofStream == null) {
        debugPrint('HardwareService: eofStream is null');
        return false;
      }
      
      final pcm16Stream = opusStream.transform(_opusToPcm16Transformer!);
      final pcm24Stream = pcm16Stream.transform(_pcm16ToPcm24Transformer!);
      
      // Store the PCM24 stream
      _pcm24Stream = pcm24Stream;

      // Store the Opus packet subscription
      _opusPacketSubscription = opusStream.listen(
        (opusPacket) {
          debugPrint('HardwareService: Received Opus packet: ${opusPacket.length} bytes');
        },
        onError: (e) {
          debugPrint('HardwareService: Error in Opus stream: $e');
        },
      );
      
      // Listen for PCM24 chunks (transformed from Opus packets)
      _pcm24ChunkSubscription = pcm24Stream.listen(
        (pcm24Chunk) {
          debugPrint('HardwareService: Processed PCM24 chunk: ${pcm24Chunk.length} bytes');
          OpenAIService.instance.sendAudio(pcm24Chunk, queryOrigin.Hardware);
        },
        onError: (e) {
          debugPrint('HardwareService: Error in PCM24 stream: $e');
        },
      );

      // Listen for EOF stream
      _eofSubscription = eofStream.listen(
        (_) {
          debugPrint('HardwareService: EOF received');
          OpenAIService.instance.createResponse();
        },
        onError: (e) {
          debugPrint('HardwareService: Error in EOF stream: $e');
        },
      );
      
      // Initialize battery controller
      _batteryController = StreamController<int>.broadcast();
      
      // Listen for connection state changes to manage battery polling
      final connectionStateStream = _bleService.connectionStateStream;
      if (connectionStateStream != null) {
        _connectionStateSubscription = connectionStateStream.listen(
          (isConnected) {
            if (isConnected) {
              _startBatteryPolling();
            } else {
              _stopBatteryPolling();
            }
          },
          onError: (e) {
            debugPrint('HardwareService: Error in connection state stream: $e');
          },
        );
      }
      
      // Start battery polling if already connected
      if (_bleService.isConnected) {
        _startBatteryPolling();
      }
      
      _startOpenAiToBleRelayer();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing HardwareService: $e');
      return false;
    }
  }


  /// Transforms Opus packets and queues them for sending to ESP32
  Future<void> _startOpenAiToBleRelayer() async {
    try {
      const int sampleRate = 16000;
      const int channels = 1;
    
      // Create Opus encoder for 60ms frames
      final encoder = StreamOpusEncoder.bytes(
        floatInput: false,
        frameTime: FrameTime.ms60,
        sampleRate: sampleRate,
        channels: channels,
        application: Application.audio,
        copyOutput: true,
        fillUpLastFrame: true,
      );
      
      // Create transformers
      final resampleTransformer = Pcm24ToPcm16Transformer();
      final encodeTransformer = Pcm16ToOpusTransformer(encoder);
      
      // Build the stream pipeline:
      // WAV file -> 60ms PCM24 chunks -> Resample to PCM16 -> Encode to Opus
      final pcm24ChunkStream = OpenAIService.instance.hardWareAudioOutStream;
      final pcm16ChunkStream = pcm24ChunkStream.transform(resampleTransformer);
      final opusPacketStream = pcm16ChunkStream.transform(encodeTransformer);
      
      // Create packets and enqueue them for sending
      await for (final opusPacket in opusPacketStream) {
        // Create packet: [length (2 bytes)] + [opus data]
        Uint8List packet = Uint8List(2 + opusPacket.length);
        packet[0] = opusPacket.length & 0xFF;
        packet[1] = (opusPacket.length >> 8) & 0xFF;
        packet.setRange(2, 2 + opusPacket.length, opusPacket);
        
        // Enqueue packet - BLE service will handle batching and sending
        _bleService.enqueuePacket(packet);
        
        _framesSent++;
        debugPrint('[QUEUE] Enqueued frame $_framesSent (${opusPacket.length} bytes Opus)');
      }
    } catch (e) {
      debugPrint('Error sending WAV to ESP32: $e');
      rethrow;
    }
  }

  Future<void> sendEOFToEsp32() async {
    // Enqueue EOF packet - it will be sent after all queued audio packets
    debugPrint('[QUEUE] Enqueuing EOF signal. Total frames sent: $_framesSent');
    _bleService.enqueueEOF();
  }

  /// Read battery percentage from device
  Future<int?> readBattery() async {
    final batteryCharacteristic = _bleService.batteryCharacteristic;
    if (!_bleService.isConnected || batteryCharacteristic == null) {
      return null;
    }

    try {
      final data = await batteryCharacteristic.read();
      if (data.length >= 3) {
        // Format: [voltage_msb, voltage_lsb, soc_percent]
        final socPercent = data[2];
        _batteryController?.add(socPercent);
        return socPercent;
      }
    } catch (e) {
      debugPrint('Error reading battery: $e');
    }
    return null;
  }
  
  void _startBatteryPolling() {
    _stopBatteryPolling(); // Stop any existing timer
    
    final batteryCharacteristic = _bleService.batteryCharacteristic;
    if (!_bleService.isConnected || batteryCharacteristic == null) {
      return;
    }
    
    // Read battery immediately
    readBattery();
    
    // Poll every 5 minutes
    _batteryPollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      readBattery();
    });
  }
  
  void _stopBatteryPolling() {
    _batteryPollTimer?.cancel();
    _batteryPollTimer = null;
  }

  /// Read RTC time from device (includes timezone)
  Future<RTCTime?> readRTC() async {
    final rtcCharacteristic = _bleService.rtcCharacteristic;
    if (!_bleService.isConnected || rtcCharacteristic == null) {
      return null;
    }

    try {
      final data = await rtcCharacteristic.read();
      if (data.length >= 7) {
        // Accept 7 bytes (backward compatibility) or 9 bytes (with timezone)
        return RTCTime.fromBytes(Uint8List.fromList(data));
      }
    } catch (e) {
      debugPrint('Error reading RTC: $e');
    }
    return null;
  }

  /// Write RTC time to device
  Future<bool> writeRTC(RTCTime time) async {
    final rtcCharacteristic = _bleService.rtcCharacteristic;
    if (!_bleService.isConnected || rtcCharacteristic == null) {
      return false;
    }
    // print time
    debugPrint('RTC time to write: ${time.toString()}');
    try {
      final data = time.toBytes();
      await rtcCharacteristic.write(data, withoutResponse: false);
      debugPrint('RTC time written: ${time.toString()}');
      return true;
    } catch (e) {
      debugPrint('Error writing RTC: $e');
      return false;
    }
  }

  /// Set RTC time from current system time (preserves existing timezone)
  Future<bool> setRTCTimeNow() async {
    // Read current RTC to get timezone
    final currentRTC = await readRTC();
    final now = DateTime.now();
    
    // Preserve timezone from current RTC, or use default PST
    final rtcTime = RTCTime.fromDateTime(
      now,
      timezoneHours: currentRTC?.timezoneHours ?? -8,
      timezoneMinutes: currentRTC?.timezoneMinutes ?? 0,
    );
    return await writeRTC(rtcTime);
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

  Future<void> dispose() async {
    await _opusPacketSubscription?.cancel();
    await _pcm24ChunkSubscription?.cancel();
    await _eofSubscription?.cancel();
    await _connectionStateSubscription?.cancel();
    
    _stopBatteryPolling();
    await _batteryController?.close();
    
    _opusPacketSubscription = null;
    _pcm24ChunkSubscription = null;
    _eofSubscription = null;
    _connectionStateSubscription = null;
    _batteryController = null;
    _streamDecoder = null;
    _opusToPcm16Transformer = null;
    _pcm16ToPcm24Transformer = null;
    _pcm24Stream = null;
    _isInitialized = false;
  }
}


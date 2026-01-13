import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:opus_dart/opus_dart.dart';
import 'audio.dart';
import 'ble_queue.dart';

/// Handles audio RX/TX characteristic communication for BLE
class BLEAudioTransport {
  // Signal constants
  static const int signalEof = 0xFFFC;
  static const int signalPause = 0xFFFE;
  static const int signalResume = 0xFFFD;
  static const int signalAudioPacket = 0x0001;
  
  BluetoothCharacteristic? _audioTxCharacteristic;
  BluetoothCharacteristic? _audioRxCharacteristic;
  StreamSubscription? _notificationSubscription;
  
  // Audio processing
  StreamController<Uint8List>? _opusPacketController;
  StreamController<void>? _eofController;
  StreamOpusDecoder? _streamDecoder;
  OpusToPcm16Transformer? _opusToPcm16Transformer;
  Pcm16ToPcm24Transformer? _pcm16ToPcm24Transformer;
  Stream<Uint8List>? _pcm24Stream;
  
  // Packet queue and stream subscriptions
  PacketQueue? _packetQueue;
  StreamSubscription<Uint8List>? _pcm24ChunkSubscription;
  StreamSubscription<void>? _eofSubscription;
  
  // Callbacks for handling processed audio
  final void Function(Uint8List)? onPcm24Chunk;
  final void Function()? onEof;
  
  // Stream for OpenAI to BLE relayer
  final Stream<Uint8List>? _openAiAudioOutStream;
  
  // Dependencies for PacketQueue (provided via callbacks)
  final bool Function()? _isConnected;
  final int Function()? _getMTU;
  
  int _framesSent = 0;
  bool _paused = false;
  bool _audioProcessingInitialized = false;
  
  BLEAudioTransport({
    this.onPcm24Chunk,
    this.onEof,
    Stream<Uint8List>? openAiAudioOutStream,
    bool Function()? isConnected,
    int Function()? getMTU,
  }) : _isConnected = isConnected,
       _getMTU = getMTU,
       _openAiAudioOutStream = openAiAudioOutStream;
  
  /// Initialize audio TX and RX characteristics from discovered service and subscribe to notifications
  Future<bool> initializeAudioTransportCharacteristics(BluetoothService service, String audioTxUuid, String audioRxUuid) async {
    _audioTxCharacteristic = null;
    _audioRxCharacteristic = null;
    
    for (BluetoothCharacteristic char in service.characteristics) {
      if (char.uuid.toString().toLowerCase() == audioTxUuid.toLowerCase()) {
        _audioTxCharacteristic = char;
        debugPrint('Found Audio TX characteristic');
      } else if (char.uuid.toString().toLowerCase() == audioRxUuid.toLowerCase()) {
        _audioRxCharacteristic = char;
        debugPrint('Found Audio RX characteristic');
      }
    }
    
    if (_audioTxCharacteristic == null || _audioRxCharacteristic == null) {
      debugPrint('Failed to initialize audio TX/RX characteristics');
      return false;
    }
    
    // Subscribe to audio TX notifications (incoming data from ESP32)
    if (_audioTxCharacteristic == null) {
      return false;
    }
    
    try {
      await _audioTxCharacteristic!.setNotifyValue(true);
      _notificationSubscription = _audioTxCharacteristic!.lastValueStream.listen(
        _handleNotification,
        onError: (error) {
          debugPrint('Notification error: $error');
        },
      );
      debugPrint('Subscribed to audio notifications');
      return true;
    } catch (e) {
      debugPrint('Error subscribing to notifications: $e');
      return false;
    }
  }
  
  /// Subscribe to audio TX notifications (incoming data from ESP32)
  Future<bool> subscribeToNotifications() async {
    if (_audioTxCharacteristic == null) {
      return false;
    }
    
    try {
      await _audioTxCharacteristic!.setNotifyValue(true);
      _notificationSubscription = _audioTxCharacteristic!.lastValueStream.listen(
        _handleNotification,
        onError: (error) {
          debugPrint('Notification error: $error');
        },
      );
      debugPrint('Subscribed to audio notifications');
      return true;
    } catch (e) {
      debugPrint('Error subscribing to notifications: $e');
      return false;
    }
  }
  
  /// Unsubscribe from audio TX notifications
  Future<void> unsubscribeFromNotifications() async {
    if (_audioTxCharacteristic != null) {
      try {
        await _audioTxCharacteristic!.setNotifyValue(false);
      } catch (e) {
        debugPrint('Error unsubscribing: $e');
      }
    }
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }
  
  /// Handle incoming notifications from audio TX characteristic
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
          continue;
        }
        if (identifier == signalResume) {
          debugPrint('[FLOW] Received RESUME signal (0xFFFD) - resuming transmission');
          _paused = false;
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

          // Emit Opus packet to stream controller
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
  
  /// Initialize audio processing pipeline (decoders and transformers)
  void initializeAudioProcessing() {
    if (_audioProcessingInitialized) return;
    
    // Initialize stream controllers
    _opusPacketController = StreamController<Uint8List>.broadcast();
    _eofController = StreamController<void>.broadcast();
    
    // Create decoder and transformers
    _streamDecoder = AudioProcessor.createDecoder();
    _opusToPcm16Transformer = OpusToPcm16Transformer(_streamDecoder!);
    _pcm16ToPcm24Transformer = Pcm16ToPcm24Transformer();
    
    // Set up the stream pipeline: Opus packets -> PCM16 -> PCM24 chunks
    final opusStream = opusPacketStream;
    if (opusStream != null) {
      final pcm16Stream = opusStream.transform(_opusToPcm16Transformer!);
      _pcm24Stream = pcm16Stream.transform(_pcm16ToPcm24Transformer!);
    }
    
    // Initialize packet queue if dependencies are provided
    if (_isConnected != null && _getMTU != null) {
      _packetQueue = PacketQueue(
        isConnected: _isConnected!,
        getMTU: _getMTU!,
        getRxCharacteristic: () => audioRxCharacteristic,
        isPaused: () => isPaused,
      );
      _packetQueue?.start();
    }
    
    // Set up stream subscriptions if callbacks are provided
    if (onPcm24Chunk != null && _pcm24Stream != null) {
      _pcm24ChunkSubscription = _pcm24Stream!.listen(
        (pcm24Chunk) {
          debugPrint('BLEAudioTransport: Processed PCM24 chunk: ${pcm24Chunk.length} bytes');
          onPcm24Chunk!(pcm24Chunk);
        },
        onError: (e) {
          debugPrint('BLEAudioTransport: Error in PCM24 stream: $e');
        },
      );
    }
    
    if (onEof != null && eofStream != null) {
      _eofSubscription = eofStream!.listen(
        (_) {
          debugPrint('BLEAudioTransport: EOF received');
          onEof!();
        },
        onError: (e) {
          debugPrint('BLEAudioTransport: Error in EOF stream: $e');
        },
      );
    }
    
    // Start OpenAI to BLE relayer if stream is provided
    if (_openAiAudioOutStream != null) {
      startOpenAiToBleRelayer(_openAiAudioOutStream!);
    }
    
    _audioProcessingInitialized = true;
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
  
  /// Send EOF to ESP32 (enqueues EOF packet)
  Future<void> sendEOFToEsp32() async {
    debugPrint('[QUEUE] Enqueuing EOF signal. Total frames sent: $_framesSent');
    enqueueEOF();
  }
  
  /// Get frames sent count
  int get framesSent => _framesSent;
  
  /// Increment frames sent count
  void incrementFramesSent() {
    _framesSent++;
  }
  
  /// Start OpenAI to BLE relayer (transforms PCM24 chunks and queues them for sending)
  Future<void> startOpenAiToBleRelayer(Stream<Uint8List> pcm24ChunkStream) async {
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
      // PCM24 chunks -> Resample to PCM16 -> Encode to Opus
      final pcm16ChunkStream = pcm24ChunkStream.transform(resampleTransformer);
      final opusPacketStream = pcm16ChunkStream.transform(encodeTransformer);
      
      // Create packets and enqueue them for sending
      await for (final opusPacket in opusPacketStream) {
        // Create packet: [length (2 bytes)] + [opus data]
        Uint8List packet = Uint8List(2 + opusPacket.length);
        packet[0] = opusPacket.length & 0xFF;
        packet[1] = (opusPacket.length >> 8) & 0xFF;
        packet.setRange(2, 2 + opusPacket.length, opusPacket);
        
        // Enqueue packet
        enqueuePacket(packet);
        
        incrementFramesSent();
        // debugPrint('[QUEUE] Enqueued frame $_framesSent (${opusPacket.length} bytes Opus)');
      }
    } catch (e) {
      debugPrint('Error sending WAV to ESP32: $e');
      rethrow;
    }
  }
  
  /// Get Opus packet stream
  Stream<Uint8List>? get opusPacketStream => _opusPacketController?.stream;
  
  /// Get EOF stream
  Stream<void>? get eofStream => _eofController?.stream;
  
  /// Get PCM24 stream (processed audio)
  Stream<Uint8List>? get pcm24Stream => _pcm24Stream;
  
  /// Get audio RX characteristic for external use (e.g., PacketQueue)
  BluetoothCharacteristic? get audioRxCharacteristic => _audioRxCharacteristic;
  
  /// Get pause state
  bool get isPaused => _paused;
  
  /// Reset pause state
  void resetPauseState() {
    _paused = false;
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await unsubscribeFromNotifications();
    _packetQueue?.dispose();
    await _pcm24ChunkSubscription?.cancel();
    await _eofSubscription?.cancel();
    await _opusPacketController?.close();
    await _eofController?.close();
    _opusPacketController = null;
    _eofController = null;
    _streamDecoder = null;
    _opusToPcm16Transformer = null;
    _pcm16ToPcm24Transformer = null;
    _pcm24Stream = null;
    _packetQueue = null;
    _pcm24ChunkSubscription = null;
    _eofSubscription = null;
    _audioProcessingInitialized = false;
    _audioTxCharacteristic = null;
    _audioRxCharacteristic = null;
  }
}


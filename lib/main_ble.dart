import 'dart:typed_data';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_dart/opus_dart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'services/ble_service.dart';
import 'services/audio_service.dart';

// ============================================================================
// MAIN APP
// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initOpus(await opus_flutter.load());
  runApp(const BLEOpusReceiver());
}

class BLEOpusReceiver extends StatelessWidget {
  const BLEOpusReceiver({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('BLE Opus Receiver'),
        ),
        body: const BLEOpusReceiverScreen(),
      ),
    );
  }
}

// ============================================================================
// AUDIO PROCESSING MODULE
// ============================================================================

class AudioProcessor {
  static const int defaultSampleRate = 16000;
  static const int defaultChannels = 1;
  
  /// Creates a new Opus decoder for streaming
  static StreamOpusDecoder createDecoder({
    int sampleRate = defaultSampleRate,
    int channels = defaultChannels,
  }) {
    return StreamOpusDecoder.bytes(
      floatOutput: false,
      sampleRate: sampleRate,
      channels: channels,
      copyOutput: true,
      forwardErrorCorrection: false,
    );
  }
  
  /// Decodes Opus packets to PCM16
  static Future<Uint8List> decodeOpusPackets(
    List<Uint8List> opusPackets, {
    int sampleRate = defaultSampleRate,
    int channels = defaultChannels,
  }) async {
    if (opusPackets.isEmpty) {
      throw Exception('No Opus packets to decode');
    }

    final decoder = createDecoder(sampleRate: sampleRate, channels: channels);
    List<Uint8List> decodedChunks = [];
    
    await for (final chunk in decoder.bind(Stream.fromIterable(opusPackets))) {
      if (chunk is Uint8List) {
        decodedChunks.add(chunk);
      }
    }

    // Combine all decoded chunks
    int totalLength = decodedChunks.fold(0, (sum, chunk) => sum + chunk.length);
    Uint8List result = Uint8List(totalLength);
    int offset = 0;
    for (Uint8List chunk in decodedChunks) {
      if (offset + chunk.length <= result.length) {
        result.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
    }

    return result;
  }
  
  /// Resamples PCM16 from 16kHz to 24kHz
  static Uint8List resamplePcm16To24(Uint8List pcm16Data) {
    const int inputSampleRate = 16000;
    const int outputSampleRate = 24000;
    const double ratio = outputSampleRate / inputSampleRate;
    const int bytesPerSample = 2;
    
    int inputSampleCount = pcm16Data.length ~/ bytesPerSample;
    int outputSampleCount = (inputSampleCount * ratio).round();
    int outputLength = outputSampleCount * bytesPerSample;
    
    Uint8List output = Uint8List(outputLength);
    Int16List inputSamples = Int16List.view(
      pcm16Data.buffer, 
      pcm16Data.offsetInBytes, 
      inputSampleCount
    );
    Int16List outputSamples = Int16List.view(
      output.buffer, 
      output.offsetInBytes, 
      outputSampleCount
    );
    
    for (int i = 0; i < outputSampleCount; i++) {
      double inputIndex = i / ratio;
      int inputIndexFloor = inputIndex.floor();
      int inputIndexCeil = (inputIndex + 1).floor();
      double fraction = inputIndex - inputIndexFloor;
      
      if (inputIndexCeil >= inputSampleCount) {
        inputIndexCeil = inputSampleCount - 1;
      }
      
      int sample1 = inputSamples[inputIndexFloor];
      int sample2 = inputSamples[inputIndexCeil];
      int interpolated = (sample1 + (sample2 - sample1) * fraction).round();
      
      outputSamples[i] = interpolated;
    }
    
    return output;
  }
  
  /// Resamples PCM24 from 24kHz to 16kHz
  static Uint8List resamplePcm24To16(Uint8List pcm24Data) {
    const int inputSampleRate = 24000;
    const int outputSampleRate = 16000;
    const double ratio = outputSampleRate / inputSampleRate;
    const int bytesPerSample = 2;
    
    int inputSampleCount = pcm24Data.length ~/ bytesPerSample;
    int outputSampleCount = (inputSampleCount * ratio).round();
    int outputLength = outputSampleCount * bytesPerSample;
    
    Uint8List output = Uint8List(outputLength);
    Int16List inputSamples = Int16List.view(
      pcm24Data.buffer, 
      pcm24Data.offsetInBytes, 
      inputSampleCount
    );
    Int16List outputSamples = Int16List.view(
      output.buffer, 
      output.offsetInBytes, 
      outputSampleCount
    );
    
    for (int i = 0; i < outputSampleCount; i++) {
      double inputIndex = i / ratio;
      int inputIndexFloor = inputIndex.floor();
      int inputIndexCeil = (inputIndex + 1).floor();
      double fraction = inputIndex - inputIndexFloor;
      
      if (inputIndexCeil >= inputSampleCount) {
        inputIndexCeil = inputSampleCount - 1;
      }
      
      int sample1 = inputSamples[inputIndexFloor];
      int sample2 = inputSamples[inputIndexCeil];
      int interpolated = (sample1 + (sample2 - sample1) * fraction).round();
      
      outputSamples[i] = interpolated;
    }
    
    return output;
  }
  
  /// Converts PCM data to WAV format
  static Uint8List pcmToWav(
    Uint8List pcmData, {
    int sampleRate = 16000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;
    final ByteData wavHeader = ByteData(44);

    // RIFF header
    wavHeader.setUint8(0, 0x52); // 'R'
    wavHeader.setUint8(1, 0x49); // 'I'
    wavHeader.setUint8(2, 0x46); // 'F'
    wavHeader.setUint8(3, 0x46); // 'F'
    wavHeader.setUint32(4, fileSize, Endian.little);
    wavHeader.setUint8(8, 0x57);  // 'W'
    wavHeader.setUint8(9, 0x41);  // 'A'
    wavHeader.setUint8(10, 0x56); // 'V'
    wavHeader.setUint8(11, 0x45); // 'E'

    // fmt chunk
    wavHeader.setUint8(12, 0x66); // 'f'
    wavHeader.setUint8(13, 0x6D); // 'm'
    wavHeader.setUint8(14, 0x74); // 't'
    wavHeader.setUint8(15, 0x20); // ' '
    wavHeader.setUint32(16, 16, Endian.little);
    wavHeader.setUint16(20, 1, Endian.little);
    wavHeader.setUint16(22, channels, Endian.little);
    wavHeader.setUint32(24, sampleRate, Endian.little);
    wavHeader.setUint32(28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
    wavHeader.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    wavHeader.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    wavHeader.setUint8(36, 0x64); // 'd'
    wavHeader.setUint8(37, 0x61); // 'a'
    wavHeader.setUint8(38, 0x74); // 't'
    wavHeader.setUint8(39, 0x61); // 'a'
    wavHeader.setUint32(40, dataSize, Endian.little);

    final Uint8List wavData = Uint8List(44 + dataSize);
    wavData.setRange(0, 44, wavHeader.buffer.asUint8List());
    wavData.setRange(44, 44 + dataSize, pcmData);

    return wavData;
  }
}

// ============================================================================
// FILE MANAGEMENT MODULE
// ============================================================================

class FileManager {
  /// Builds Opus file header
  static Uint8List buildOpusHeader(int sampleRate, int frameSize) {
    final header = Uint8List(12);
    header[0] = 0x4F; // 'O'
    header[1] = 0x50; // 'P'
    header[2] = 0x55; // 'U'
    header[3] = 0x53; // 'S'
    header[4] = sampleRate & 0xFF;
    header[5] = (sampleRate >> 8) & 0xFF;
    header[6] = (sampleRate >> 16) & 0xFF;
    header[7] = (sampleRate >> 24) & 0xFF;
    header[8] = frameSize & 0xFF;
    header[9] = (frameSize >> 8) & 0xFF;
    header[10] = (frameSize >> 16) & 0xFF;
    header[11] = (frameSize >> 24) & 0xFF;
    return header;
  }
  
  /// Saves Opus file with packets
  static Future<String> saveOpusFile(
    List<Uint8List> opusPackets,
    int timestamp, {
    int sampleRate = 16000,
    int frameSize = 1920,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final opusPath = '${directory.path}/recording_$timestamp.opus';
    final opusFile = File(opusPath);

    final opusHeader = buildOpusHeader(sampleRate, frameSize);
    int totalLength = opusHeader.length;
    for (Uint8List packet in opusPackets) {
      totalLength += 2 + packet.length;
    }
    
    Uint8List concatenatedData = Uint8List(totalLength);
    concatenatedData.setRange(0, opusHeader.length, opusHeader);
    
    int offset = opusHeader.length;
    for (Uint8List packet in opusPackets) {
      concatenatedData[offset] = packet.length & 0xFF;
      concatenatedData[offset + 1] = (packet.length >> 8) & 0xFF;
      offset += 2;
      concatenatedData.setRange(offset, offset + packet.length, packet);
      offset += packet.length;
    }

    await opusFile.writeAsBytes(concatenatedData);
    return opusPath;
  }
  
  /// Saves WAV file from PCM24 chunks
  static Future<String> saveWavFile(
    List<Uint8List> pcm24Chunks,
    int timestamp, {
    int sampleRate = 24000,
  }) async {
    if (pcm24Chunks.isEmpty) {
      throw Exception('No PCM24 data to save');
    }

    int totalLength = pcm24Chunks.fold(0, (sum, chunk) => sum + chunk.length);
    Uint8List pcm24Data = Uint8List(totalLength);
    int offset = 0;
    for (Uint8List chunk in pcm24Chunks) {
      pcm24Data.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    final wavData = AudioProcessor.pcmToWav(pcm24Data, sampleRate: sampleRate);
    final directory = await getApplicationDocumentsDirectory();
    final wavPath = '${directory.path}/recording_$timestamp.wav';
    final wavFile = File(wavPath);
    await wavFile.writeAsBytes(wavData);
    
    return wavPath;
  }
  
  /// Shares a file using the platform share dialog
  static Future<void> shareFile(
    String filePath,
    String text,
    String subject,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }
    final xFile = XFile(filePath);
    await Share.shareXFiles([xFile], text: text, subject: subject);
  }
}

// ============================================================================
// AUDIO PLAYBACK MODULE
// ============================================================================

class AudioPlaybackManager {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  /// Plays Opus file by decoding to PCM and converting to WAV
  Future<void> playOpusFile(
    String opusFilePath,
    List<Uint8List> opusPackets,
  ) async {
    if (opusFilePath.isEmpty || opusPackets.isEmpty) {
      throw Exception('No Opus file or packets to play');
    }

    final opusFile = File(opusFilePath);
    if (!await opusFile.exists()) {
      throw Exception('Opus file does not exist: $opusFilePath');
    }

    final pcmData = await AudioProcessor.decodeOpusPackets(opusPackets);
    if (pcmData.isEmpty) {
      throw Exception('Decoded PCM data is empty');
    }

    const int sampleRate = 16000;
    final wavData = AudioProcessor.pcmToWav(pcmData, sampleRate: sampleRate);

    final directory = await getTemporaryDirectory();
    final tempWavPath = '${directory.path}/temp_playback_${DateTime.now().millisecondsSinceEpoch}.wav';
    final tempWavFile = File(tempWavPath);
    await tempWavFile.writeAsBytes(wavData);

    await _audioPlayer.play(DeviceFileSource(tempWavPath));
    await _audioPlayer.onPlayerComplete.first;
    await tempWavFile.delete();
  }
  
  void dispose() {
    _audioPlayer.dispose();
  }
}

// ============================================================================
// AUDIO TRANSMITTER MODULE
// ============================================================================

class AudioTransmitter {
  final BLEService _bleService;
  
  AudioTransmitter(this._bleService);
  
  /// Sends WAV file back to ESP32 as Opus packets
  Future<void> sendWavToEsp32(String wavFilePath) async {
    final wavFile = File(wavFilePath);
    if (!await wavFile.exists()) {
      throw Exception('WAV file does not exist: $wavFilePath');
    }

    final wavData = await wavFile.readAsBytes();
    if (wavData.length < 44) {
      throw Exception('WAV file too small');
    }

    final pcm24Data = wavData.sublist(44);
    final pcm16Data = AudioProcessor.resamplePcm24To16(pcm24Data);
    await encodeAndSendPcm16(pcm16Data);
  }
  
  /// Encodes PCM16 to Opus and sends to ESP32
  Future<void> encodeAndSendPcm16(Uint8List pcm16Data) async {
    const int sampleRate = 16000;
    const int channels = 1;
    const int frameSize = 960;
    const int frameSizeBytes = frameSize * 2;
    
    final encoder = StreamOpusEncoder.bytes(
      floatInput: false,
      frameTime: FrameTime.ms60,
      sampleRate: sampleRate,
      channels: channels,
      application: Application.audio,
      copyOutput: true,
      fillUpLastFrame: true,
    );
    
    List<Uint8List> frameBuffer = [];
    int offset = 0;
    
    while (offset < pcm16Data.length) {
      int frameEnd = (offset + frameSizeBytes < pcm16Data.length) 
          ? offset + frameSizeBytes 
          : pcm16Data.length;
      
      Uint8List frame = pcm16Data.sublist(offset, frameEnd);
      
      if (frame.length < frameSizeBytes) {
        Uint8List paddedFrame = Uint8List(frameSizeBytes);
        paddedFrame.setRange(0, frame.length, frame);
        frame = paddedFrame;
      }
      
      frameBuffer.add(frame);
      offset += frameSizeBytes;
    }
    
    final mtu = _bleService.getMTU();
    Uint8List batch = Uint8List(0);
    int framesSent = 0;
    
    await for (final opusPacket in encoder.bind(Stream.fromIterable(frameBuffer))) {
      if (opusPacket.isNotEmpty) {
        Uint8List packet = Uint8List(2 + opusPacket.length);
        packet[0] = opusPacket.length & 0xFF;
        packet[1] = (opusPacket.length >> 8) & 0xFF;
        packet.setRange(2, 2 + opusPacket.length, opusPacket);
        
        await _bleService.waitIfPaused();
        
        if (batch.length + packet.length > mtu && batch.isNotEmpty) {
          await _bleService.sendBatch(batch);
          batch = Uint8List(0);
          await Future.delayed(const Duration(milliseconds: 20));
        }
        
        Uint8List newBatch = Uint8List(batch.length + packet.length);
        if (batch.isNotEmpty) {
          newBatch.setRange(0, batch.length, batch);
        }
        newBatch.setRange(batch.length, batch.length + packet.length, packet);
        batch = newBatch;
        
        framesSent++;
        await Future.delayed(const Duration(milliseconds: 5));
      }
    }
    
    if (batch.isNotEmpty) {
      await _bleService.sendBatch(batch);
    }
    
    debugPrint('Sent EOF signal. Total frames sent: $framesSent');
    const int signalEof = 0x0000;
    Uint8List eofPacket = Uint8List(2);
    eofPacket[0] = signalEof & 0xFF;
    eofPacket[1] = (signalEof >> 8) & 0xFF;
    await _bleService.sendPacket(eofPacket);
  }
}

// ============================================================================
// STREAM TRANSFORMER MODULE
// ============================================================================

/// Transforms Opus packets to PCM24 chunks by decoding and resampling
class OpusToPcm24Transformer extends StreamTransformerBase<Uint8List, Uint8List> {
  final StreamOpusDecoder decoder;
  
  OpusToPcm24Transformer(this.decoder);
  
  @override
  Stream<Uint8List> bind(Stream<Uint8List> stream) {
    return stream.asyncExpand((opusPacket) async* {
      try {
        final decodedStream = decoder.bind(Stream.value(opusPacket));
        await for (final pcm16Chunk in decodedStream) {
          if (pcm16Chunk is Uint8List && pcm16Chunk.isNotEmpty) {
            final pcm24Chunk = AudioProcessor.resamplePcm16To24(pcm16Chunk);
            yield pcm24Chunk;
          }
        }
      } catch (e) {
        debugPrint('Error in OpusToPcm24Transformer: $e');
        // Don't yield anything on error, just log it
      }
    });
  }
}

// ============================================================================
// RECORDING STATE MODULE
// ============================================================================

class RecordingState {
  final List<Uint8List> opusPackets = [];
  final List<Uint8List> pcm24Chunks = [];
  int packetCount = 0;
  int? recordingTimestamp;
  
  void reset() {
    opusPackets.clear();
    pcm24Chunks.clear();
    packetCount = 0;
    recordingTimestamp = null;
  }
  
  void addOpusPacket(Uint8List packet) {
    if (recordingTimestamp == null) {
      recordingTimestamp = DateTime.now().millisecondsSinceEpoch;
    }
    opusPackets.add(packet);
    packetCount++;
  }
  
  void addPcm24Chunk(Uint8List chunk) {
    pcm24Chunks.add(chunk);
  }
  
  int getTimestamp() {
    return recordingTimestamp ?? DateTime.now().millisecondsSinceEpoch;
  }
}

// ============================================================================
// MAIN SCREEN WIDGET
// ============================================================================

class BLEOpusReceiverScreen extends StatefulWidget {
  const BLEOpusReceiverScreen({super.key});

  @override
  State<BLEOpusReceiverScreen> createState() => _BLEOpusReceiverScreenState();
}

class _BLEOpusReceiverScreenState extends State<BLEOpusReceiverScreen> {
  final BLEService _bleService = BLEService();
  final AudioService _audioService = AudioService();
  final AudioPlaybackManager _playbackManager = AudioPlaybackManager();
  late final AudioTransmitter _transmitter;
  final RecordingState _recordingState = RecordingState();
  
  bool _isConnected = false;
  bool _isReceiving = false;
  bool _isPlaying = false;
  String? _opusFilePath;
  String? _wavFilePath;
  StreamSubscription<Uint8List>? _opusPacketSubscription;
  StreamSubscription<Uint8List>? _pcm24ChunkSubscription;
  StreamSubscription<void>? _eofSubscription;
  StreamOpusDecoder? _streamDecoder;
  OpusToPcm24Transformer? _opusTransformer;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _bleService.initialize();
    await _audioService.initialize();
    
    _transmitter = AudioTransmitter(_bleService);
    _streamDecoder = AudioProcessor.createDecoder();
    _opusTransformer = OpusToPcm24Transformer(_streamDecoder!);
    
    // Set up the stream pipeline: Opus packets -> PCM24 chunks
    final opusStream = _bleService.opusPacketStream;
    if (opusStream != null) {
      final pcm24Stream = opusStream.transform(_opusTransformer!);
      
      // Listen for Opus packets (for saving)
      _opusPacketSubscription = opusStream.listen(
        (packet) {
          _recordingState.addOpusPacket(packet);
          setState(() {
            _isReceiving = true;
          });
          debugPrint('Received Opus packet ${_recordingState.packetCount}: ${packet.length} bytes');
        },
      );
      
      // Listen for PCM24 chunks (transformed from Opus packets)
      _pcm24ChunkSubscription = pcm24Stream.listen(
        (pcm24Chunk) {
          _recordingState.addPcm24Chunk(pcm24Chunk);
          debugPrint('Processed chunk: ${pcm24Chunk.length} bytes PCM24');
        },
        onError: (e) {
          debugPrint('Error in PCM24 stream: $e');
        },
      );
    }

    _eofSubscription = _bleService.eofStream?.listen(
      (_) async {
        debugPrint('EOF received, finalizing files...');
        await _finalizeFiles();
        
        if (_wavFilePath != null) {
          await _transmitter.sendWavToEsp32(_wavFilePath!);
        }
        
        setState(() {
          _isReceiving = false;
        });
      },
    );
  }

  Future<void> _connectToDevice() async {
    setState(() {
      _isConnected = false;
      _opusFilePath = null;
      _wavFilePath = null;
      _recordingState.reset();
    });
    
    _streamDecoder = AudioProcessor.createDecoder();

    final success = await _bleService.scanAndConnect();
    if (success) {
      setState(() {
        _isConnected = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to ESP32 device')),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await _bleService.disconnect();
    setState(() {
      _isConnected = false;
      _isReceiving = false;
    });
  }

  Future<void> _finalizeFiles() async {
    if (_recordingState.opusPackets.isEmpty) {
      debugPrint('No Opus packets to save');
      return;
    }

    final timestamp = _recordingState.getTimestamp();

    try {
      _opusFilePath = await FileManager.saveOpusFile(
        _recordingState.opusPackets,
        timestamp,
      );
      
      _wavFilePath = await FileManager.saveWavFile(
        _recordingState.pcm24Chunks,
        timestamp,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved ${_recordingState.opusPackets.length} packets to files'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error finalizing files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving files: $e')),
        );
      }
    }
  }

  Future<void> _playOpusFile() async {
    if (_opusFilePath == null || _recordingState.opusPackets.isEmpty) return;

    setState(() {
      _isPlaying = true;
    });

    try {
      await _playbackManager.playOpusFile(
        _opusFilePath!,
        _recordingState.opusPackets,
      );
    } catch (e) {
      debugPrint('Error playing Opus file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing Opus file: $e')),
        );
      }
    } finally {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _shareOpusFile() async {
    if (_opusFilePath == null) return;
    try {
      await FileManager.shareFile(
        _opusFilePath!,
        'Opus audio file from ESP32',
        'Opus Recording',
      );
    } catch (e) {
      debugPrint('Error sharing file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  Future<void> _shareWavFile() async {
    if (_wavFilePath == null) return;
    try {
      await FileManager.shareFile(
        _wavFilePath!,
        'WAV audio file from ESP32',
        'WAV Recording',
      );
    } catch (e) {
      debugPrint('Error sharing WAV file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing WAV file: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _opusPacketSubscription?.cancel();
    _pcm24ChunkSubscription?.cancel();
    _eofSubscription?.cancel();
    _bleService.dispose();
    _playbackManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Connection status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        color: _isConnected ? Colors.green : Colors.grey,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (_isReceiving) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text('Receiving packets: ${_recordingState.packetCount}'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Connection controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _isConnected ? null : _connectToDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Connect'),
              ),
              ElevatedButton(
                onPressed: _isConnected ? _disconnect : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Disconnect'),
              ),
            ],
          ),

          // Opus file section
          if (_opusFilePath != null) ...[
            const Divider(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Opus File:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _opusFilePath!.split('/').last,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_recordingState.opusPackets.length} packets',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isPlaying ? null : _playOpusFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: _isPlaying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.play_arrow),
                          label: const Text('Play'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _shareOpusFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.share),
                          label: const Text('Share Opus'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // WAV file section
          if (_wavFilePath != null) ...[
            const Divider(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'WAV File:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _wavFilePath!.split('/').last,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _shareWavFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text('Share/Download WAV'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_dart/opus_dart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'services/ble_service.dart';
import 'services/audio_service.dart';

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

class BLEOpusReceiverScreen extends StatefulWidget {
  const BLEOpusReceiverScreen({super.key});

  @override
  State<BLEOpusReceiverScreen> createState() => _BLEOpusReceiverScreenState();
}

class _BLEOpusReceiverScreenState extends State<BLEOpusReceiverScreen> {
  final BLEService _bleService = BLEService();
  final AudioService _audioService = AudioService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isConnected = false;
  bool _isReceiving = false;
  bool _isPlaying = false;
  String? _opusFilePath;
  String? _wavFilePath;
  List<Uint8List> _opusPackets = [];
  List<Uint8List> _pcm24Chunks = []; // Accumulated resampled PCM24 data
  StreamSubscription<Uint8List>? _opusPacketSubscription;
  StreamSubscription<void>? _eofSubscription;
  StreamOpusDecoder? _streamDecoder;
  int _packetCount = 0;
  int? _recordingTimestamp;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _bleService.initialize();
    await _audioService.initialize();
    
    // Initialize streaming decoder
    const int sampleRate = 16000; // ESP32 uses 16kHz
    const int channels = 1;
    _streamDecoder = StreamOpusDecoder.bytes(
      floatOutput: false,
      sampleRate: sampleRate,
      channels: channels,
      copyOutput: true,
      forwardErrorCorrection: false,
    );
    
    // Listen for Opus packets - process them as they arrive
    _opusPacketSubscription = _bleService.opusPacketStream?.listen(
      (packet) async {
        // Set recording timestamp on first packet
        if (_recordingTimestamp == null) {
          _recordingTimestamp = DateTime.now().millisecondsSinceEpoch;
        }
        
        setState(() {
          _opusPackets.add(packet);
          _packetCount++;
          _isReceiving = true;
        });
        debugPrint('Received Opus packet ${_packetCount}: ${packet.length} bytes');
        
        // Process packet immediately: decode and resample
        await _processOpusPacket(packet);
      },
    );

    // Listen for EOF
    _eofSubscription = _bleService.eofStream?.listen(
      (_) async {
        debugPrint('EOF received, finalizing files...');
        await _finalizeFiles();
        setState(() {
          _isReceiving = false;
        });
      },
    );
  }

  Future<void> _processOpusPacket(Uint8List opusPacket) async {
    try {
      // Decode Opus packet to PCM16
      final decodedStream = _streamDecoder!.bind(Stream.value(opusPacket));
      await for (final pcm16Chunk in decodedStream) {
        if (pcm16Chunk is Uint8List && pcm16Chunk.isNotEmpty) {
          // Resample PCM16 to PCM24
          final pcm24Chunk = _resamplePcm16To24(pcm16Chunk);
          _pcm24Chunks.add(pcm24Chunk);
          debugPrint('Processed packet: ${opusPacket.length} bytes Opus -> ${pcm16Chunk.length} bytes PCM16 -> ${pcm24Chunk.length} bytes PCM24');
        }
      }
    } catch (e) {
      debugPrint('Error processing Opus packet: $e');
    }
  }

  Future<void> _connectToDevice() async {
    setState(() {
      _isConnected = false;
      _opusFilePath = null;
      _wavFilePath = null;
      _opusPackets.clear();
      _pcm24Chunks.clear();
      _packetCount = 0;
      _recordingTimestamp = null;
    });
    
    // Reset decoder for new recording
    const int sampleRate = 16000;
    const int channels = 1;
    _streamDecoder = StreamOpusDecoder.bytes(
      floatOutput: false,
      sampleRate: sampleRate,
      channels: channels,
      copyOutput: true,
      forwardErrorCorrection: false,
    );

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
    if (_opusPackets.isEmpty) {
      debugPrint('No Opus packets to save');
      return;
    }

    // Use recording timestamp if set, otherwise create new one
    final timestamp = _recordingTimestamp ?? DateTime.now().millisecondsSinceEpoch;
    _recordingTimestamp = timestamp;

    try {
      // Save Opus file
      await _saveOpusFile(timestamp);
      
      // Save WAV file (using accumulated PCM24 chunks)
      await _saveWavFile(timestamp);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved ${_opusPackets.length} packets to files'),
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

  Future<void> _saveOpusFile(int timestamp) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final opusPath = '${directory.path}/recording_$timestamp.opus';
      final opusFile = File(opusPath);

      // Build Opus header
      const int sampleRate = 16000; // ESP32 uses 16kHz
      const int frameSize = 1920; // 120ms at 16kHz
      final opusHeader = _buildOpusHeader(sampleRate, frameSize);

      // Calculate total size: header + (2 bytes length prefix + packet data) for each packet
      int totalLength = opusHeader.length;
      for (Uint8List packet in _opusPackets) {
        totalLength += 2 + packet.length; // 2 bytes for length prefix + packet data
      }
      
      Uint8List concatenatedData = Uint8List(totalLength);
      
      // Write header first
      concatenatedData.setRange(0, opusHeader.length, opusHeader);
      
      // Write packets with length prefixes (format expected by Python script)
      int offset = opusHeader.length;
      for (Uint8List packet in _opusPackets) {
        // Write 2-byte length prefix (little-endian uint16)
        concatenatedData[offset] = packet.length & 0xFF;
        concatenatedData[offset + 1] = (packet.length >> 8) & 0xFF;
        offset += 2;
        
        // Write packet data
        concatenatedData.setRange(offset, offset + packet.length, packet);
        offset += packet.length;
      }

      await opusFile.writeAsBytes(concatenatedData);
      debugPrint('Saved Opus file: $opusPath (${_opusPackets.length} packets, ${opusHeader.length + totalLength} bytes with header)');

      setState(() {
        _opusFilePath = opusPath;
      });
    } catch (e) {
      debugPrint('Error saving Opus file: $e');
      rethrow;
    }
  }

  Future<void> _playOpusFile() async {
    if (_opusFilePath == null || _opusPackets.isEmpty) return;

    setState(() {
      _isPlaying = true;
    });

    try {
      debugPrint('Starting Opus file playback from: $_opusFilePath');

      // Read the Opus file
      final opusFile = File(_opusFilePath!);
      if (!await opusFile.exists()) {
        throw Exception('Opus file does not exist: $_opusFilePath');
      }

      final opusData = await opusFile.readAsBytes();
      debugPrint('Read ${opusData.length} bytes from Opus file');

      if (opusData.isEmpty) {
        throw Exception('Opus file is empty');
      }

      // Decode Opus to PCM using stored packets
      final pcmData = await _convertOpusPacketsToPcm(_opusPackets);

      if (pcmData.isEmpty) {
        throw Exception('Decoded PCM data is empty');
      }

      // Convert PCM to WAV for playback (16kHz for playback)
      const int sampleRate = 16000;
      final wavData = _pcmToWav(pcmData, sampleRate: sampleRate);
      debugPrint('Created WAV data: ${wavData.length} bytes');

      // Save temporary WAV file for playback
      final directory = await getTemporaryDirectory();
      final tempWavPath = '${directory.path}/temp_playback_${DateTime.now().millisecondsSinceEpoch}.wav';
      final tempWavFile = File(tempWavPath);
      await tempWavFile.writeAsBytes(wavData);

      debugPrint('Saved temporary WAV file: $tempWavPath');

      // Play the temporary WAV file
      await _audioPlayer.play(DeviceFileSource(tempWavPath));
      await _audioPlayer.onPlayerComplete.first;

      // Clean up temporary file
      await tempWavFile.delete();
      debugPrint('Playback completed successfully');
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

  Future<Uint8List> _convertOpusPacketsToPcm(List<Uint8List> opusPackets) async {
    const int sampleRate = 16000; // ESP32 uses 16kHz
    const int channels = 1;

    try {
      debugPrint('Starting Opus to PCM conversion: ${opusPackets.length} packets');

      if (opusPackets.isEmpty) {
        throw Exception('No Opus packets to decode');
      }

      final decoder = StreamOpusDecoder.bytes(
        floatOutput: false,
        sampleRate: sampleRate,
        channels: channels,
        copyOutput: true,
        forwardErrorCorrection: false,
      );

      // Decode each packet individually
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

      debugPrint('Opus to PCM: ${opusPackets.length} packets -> ${result.length} bytes');
      return result;
    } catch (e) {
      debugPrint('Error in Opus to PCM conversion: $e');
      rethrow;
    }
  }

  Uint8List _resamplePcm16To24(Uint8List pcm16Data) {
    // Simple linear interpolation resampling from 16kHz to 24kHz
    // Ratio: 24/16 = 1.5 (output samples per input sample)
    const int inputSampleRate = 16000;
    const int outputSampleRate = 24000;
    const double ratio = outputSampleRate / inputSampleRate; // 1.5
    
    // PCM16 is 16-bit (2 bytes per sample), mono
    const int bytesPerSample = 2;
    int inputSampleCount = pcm16Data.length ~/ bytesPerSample;
    int outputSampleCount = (inputSampleCount * ratio).round();
    int outputLength = outputSampleCount * bytesPerSample;
    
    Uint8List output = Uint8List(outputLength);
    
    // Convert input to Int16List for easier manipulation
    Int16List inputSamples = Int16List.view(pcm16Data.buffer, pcm16Data.offsetInBytes, inputSampleCount);
    Int16List outputSamples = Int16List.view(output.buffer, output.offsetInBytes, outputSampleCount);
    
    // Linear interpolation resampling
    for (int i = 0; i < outputSampleCount; i++) {
      double inputIndex = i / ratio;
      int inputIndexFloor = inputIndex.floor();
      int inputIndexCeil = (inputIndex + 1).floor();
      double fraction = inputIndex - inputIndexFloor;
      
      // Handle boundary cases
      if (inputIndexCeil >= inputSampleCount) {
        inputIndexCeil = inputSampleCount - 1;
      }
      
      // Linear interpolation
      int sample1 = inputSamples[inputIndexFloor];
      int sample2 = inputSamples[inputIndexCeil];
      int interpolated = (sample1 + (sample2 - sample1) * fraction).round();
      
      outputSamples[i] = interpolated;
    }
    
    return output;
  }

  Future<void> _saveWavFile(int timestamp) async {
    if (_pcm24Chunks.isEmpty) {
      debugPrint('No PCM24 data to save as WAV');
      return;
    }

    try {
      // Combine all accumulated PCM24 chunks
      int totalLength = _pcm24Chunks.fold(0, (sum, chunk) => sum + chunk.length);
      Uint8List pcm24Data = Uint8List(totalLength);
      int offset = 0;
      for (Uint8List chunk in _pcm24Chunks) {
        pcm24Data.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      debugPrint('Combined PCM24 data: ${_pcm24Chunks.length} chunks -> ${pcm24Data.length} bytes (24kHz)');

      // Convert PCM to WAV with 24kHz sample rate
      const int sampleRate = 24000; // Upsampled to 24kHz
      final wavData = _pcmToWav(pcm24Data, sampleRate: sampleRate);

      // Save WAV file
      final directory = await getApplicationDocumentsDirectory();
      final wavPath = '${directory.path}/recording_$timestamp.wav';
      final wavFile = File(wavPath);
      await wavFile.writeAsBytes(wavData);
      
      debugPrint('Saved WAV file: $wavPath (${wavData.length} bytes)');

      setState(() {
        _wavFilePath = wavPath;
      });
    } catch (e) {
      debugPrint('Error saving WAV file: $e');
    }
  }

  Uint8List _buildOpusHeader(int sampleRate, int frameSize) {
    // Build OPUS file header: 'OPUS' (4 bytes) + sample_rate (4 bytes LE) + frame_size (4 bytes LE)
    final header = Uint8List(12);
    // Magic bytes 'OPUS'
    header[0] = 0x4F; // 'O'
    header[1] = 0x50; // 'P'
    header[2] = 0x55; // 'U'
    header[3] = 0x53; // 'S'
    // Sample rate (uint32 little-endian)
    header[4] = sampleRate & 0xFF;
    header[5] = (sampleRate >> 8) & 0xFF;
    header[6] = (sampleRate >> 16) & 0xFF;
    header[7] = (sampleRate >> 24) & 0xFF;
    // Frame size (uint32 little-endian)
    header[8] = frameSize & 0xFF;
    header[9] = (frameSize >> 8) & 0xFF;
    header[10] = (frameSize >> 16) & 0xFF;
    header[11] = (frameSize >> 24) & 0xFF;
    return header;
  }

  Future<void> _shareOpusFile() async {
    if (_opusFilePath == null) return;

    try {
      final file = File(_opusFilePath!);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File does not exist')),
          );
        }
        return;
      }

      final xFile = XFile(_opusFilePath!);
      await Share.shareXFiles(
        [xFile],
        text: 'Opus audio file from ESP32',
        subject: 'Opus Recording',
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
      final file = File(_wavFilePath!);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WAV file does not exist')),
          );
        }
        return;
      }

      final xFile = XFile(_wavFilePath!);
      await Share.shareXFiles(
        [xFile],
        text: 'WAV audio file from ESP32',
        subject: 'WAV Recording',
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

  Uint8List _pcmToWav(Uint8List pcmData, {int sampleRate = 16000, int channels = 1, int bitsPerSample = 16}) {
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
    wavHeader.setUint32(16, 16, Endian.little); // fmt chunk size
    wavHeader.setUint16(20, 1, Endian.little);  // audio format (PCM)
    wavHeader.setUint16(22, channels, Endian.little);
    wavHeader.setUint32(24, sampleRate, Endian.little);
    wavHeader.setUint32(28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little); // byte rate
    wavHeader.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little); // block align
    wavHeader.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    wavHeader.setUint8(36, 0x64); // 'd'
    wavHeader.setUint8(37, 0x61); // 'a'
    wavHeader.setUint8(38, 0x74); // 't'
    wavHeader.setUint8(39, 0x61); // 'a'
    wavHeader.setUint32(40, dataSize, Endian.little);

    // Combine header and PCM data
    final Uint8List wavData = Uint8List(44 + dataSize);
    wavData.setRange(0, 44, wavHeader.buffer.asUint8List());
    wavData.setRange(44, 44 + dataSize, pcmData);

    return wavData;
  }

  @override
  void dispose() {
    _opusPacketSubscription?.cancel();
    _eofSubscription?.cancel();
    _bleService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Connection status
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
                        Text('Receiving packets: $_packetCount'),
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
                      '${_opusPackets.length} packets',
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


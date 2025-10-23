import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_dart/opus_dart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'services/audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initOpus(await opus_flutter.load());
  runApp(const OpusFlutter());
}


class OpusFlutter extends StatelessWidget {
  const OpusFlutter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('opus_flutter'),
        ),
        body: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
              Text('Version: ${getOpusVersion()}\n'),
              const OpusExample()
            ])),
      ),
    );
  }
}

class OpusExample extends StatefulWidget {
  const OpusExample({super.key});

  @override
  State<OpusExample> createState() => _OpusExampleState();
}

class _OpusExampleState extends State<OpusExample> {
  final AudioService _audioService = AudioService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  bool _isConverting = false;
  bool _isPlaying = false;
  String? _wavFilePath;
  String? _opusFilePath;
  List<Uint8List> _opusPackets = []; // Store individual Opus packets

  @override
  void initState() {
    super.initState();
    _audioService.initialize();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final success = await _audioService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _wavFilePath = null;
        _opusFilePath = null;
        _opusPackets.clear();
      });
    }
  }

  Future<void> _stopRecording() async {
    final filePath = await _audioService.stopRecording();
    setState(() {
      _isRecording = false;
      _wavFilePath = filePath;
    });
  }

  Future<void> _playWavFile() async {
    if (_wavFilePath == null) return;
    
    setState(() {
      _isPlaying = true;
    });
    
    try {
      await _audioPlayer.play(DeviceFileSource(_wavFilePath!));
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      debugPrint('Error playing WAV file: $e');
    } finally {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _convertToOpus() async {
    if (_wavFilePath == null) return;
    
    setState(() {
      _isConverting = true;
    });
    
    try {
      // Read the WAV file
      final wavFile = File(_wavFilePath!);
      final wavData = await wavFile.readAsBytes();
      
      // Extract PCM data from WAV (skip the 44-byte header)
      final pcmData = wavData.sublist(44);
      
      // Convert PCM to Opus and store individual packets
      _opusPackets = await _convertPcmToOpusPackets(pcmData);
      
      // Save Opus file (concatenated packets for storage)
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final opusPath = '${directory.path}/recording_$timestamp.opus';
      final opusFile = File(opusPath);
      
      // Concatenate all packets for file storage
      int totalLength = _opusPackets.fold(0, (sum, packet) => sum + packet.length);
      Uint8List concatenatedData = Uint8List(totalLength);
      int offset = 0;
      for (Uint8List packet in _opusPackets) {
        concatenatedData.setRange(offset, offset + packet.length, packet);
        offset += packet.length;
      }
      await opusFile.writeAsBytes(concatenatedData);
      
      setState(() {
        _opusFilePath = opusPath;
      });
    } catch (e) {
      debugPrint('Error converting to Opus: $e');
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  Future<List<Uint8List>> _convertPcmToOpusPackets(Uint8List pcmData) async {
    const int sampleRate = 24000;
    const int channels = 1;
    
    try {
      debugPrint('Starting PCM to Opus conversion: ${pcmData.length} bytes');
      
      // Split PCM data into proper frame sizes for Opus encoding
      // For 20ms frames at 24kHz: 24000 * 0.02 * 2 bytes = 960 bytes per frame
      const int frameSizeBytes = 960; // 20ms at 24kHz, 16-bit, mono
      List<Uint8List> pcmFrames = [];
      
      for (int i = 0; i < pcmData.length; i += frameSizeBytes) {
        int end = (i + frameSizeBytes < pcmData.length) ? i + frameSizeBytes : pcmData.length;
        pcmFrames.add(pcmData.sublist(i, end));
      }
      
      // Create encoder
      final encoder = StreamOpusEncoder.bytes(
        floatInput: false,
        frameTime: FrameTime.ms20,
        sampleRate: sampleRate,
        channels: channels,
        application: Application.audio,
        copyOutput: true,
        fillUpLastFrame: true,
      );
      
      // Encode each frame
      List<Uint8List> opusPackets = [];
      await for (final packet in encoder.bind(Stream.fromIterable(pcmFrames))) {
        opusPackets.add(packet);
      }
      
      debugPrint('PCM to Opus: ${pcmData.length} bytes -> ${opusPackets.length} packets');
      return opusPackets;
    } catch (e) {
      debugPrint('Error in PCM to Opus conversion: $e');
      rethrow;
    }
  }

  Future<Uint8List> _convertOpusPacketsToPcm(List<Uint8List> opusPackets) async {
    const int sampleRate = 24000;
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

  Future<void> _playOpusFile() async {
    if (_opusFilePath == null) return;
    
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
      
      // Convert PCM to WAV for playback
      final wavData = _pcmToWav(pcmData);
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
      // Show error to user
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


  Uint8List _pcmToWav(Uint8List pcmData, {int sampleRate = 24000, int channels = 1, int bitsPerSample = 16}) {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Recording controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _isRecording ? null : _startRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Start Recording'),
              ),
              ElevatedButton(
                onPressed: _isRecording ? _stopRecording : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Stop Recording'),
              ),
            ],
          ),
          
          // Recording status
          if (_isRecording)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: Colors.red),
                SizedBox(width: 8),
                Text('Recording...', style: TextStyle(color: Colors.red)),
              ],
            ),
          
          // WAV file section
          if (_wavFilePath != null) ...[
            const Divider(),
            const Text('WAV File:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isPlaying ? null : _playWavFile,
                  child: _isPlaying 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Play WAV'),
                ),
                ElevatedButton(
                  onPressed: _isConverting ? null : _convertToOpus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isConverting 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Convert to Opus'),
                ),
              ],
            ),
          ],
          
          // Opus file section
          if (_opusFilePath != null) ...[
            const Divider(),
            const Text('Opus File:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isPlaying ? null : _playOpusFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: _isPlaying 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Play Opus'),
            ),
          ],
        ],
      ),
    );
  }
}

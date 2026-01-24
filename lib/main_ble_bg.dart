import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'bg_ble_helper.dart';
import 'bg_socket_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BleBackgroundApp());
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final bleHelper = SimpleBleHelper();
  final socketClient = BackgroundSocketClient();
  
  // Configure socket URL (default, can be changed via event)
  const defaultSocketUrl = 'ws://192.168.0.44:8080';
  await socketClient.connect(defaultSocketUrl);
  
  bleHelper.setListener(_BackgroundBleListener(service, bleHelper, socketClient));
  await bleHelper.initialize();

  service.on('ble.start').listen((event) async {
    await bleHelper.scanAndConnect();
  });

  service.on('ble.stop').listen((event) async {
    await bleHelper.disconnect();
  });

  service.on('stop').listen((event) async {
    await bleHelper.disconnect();
    await socketClient.disconnect();
    service.stopSelf();
  });

  // Socket configuration events
  service.on('socket.connect').listen((event) async {
    final url = event?['url'] ?? defaultSocketUrl;
    await socketClient.connect(url);
  });

  service.on('socket.disconnect').listen((event) async {
    await socketClient.disconnect();
  });

  // Opus file sending event
  service.on('send.opus').listen((event) async {
    await _sendOpusFile(bleHelper, service);
  });

  // Keep a small tick so we know the isolate is still alive in background.
  Timer.periodic(const Duration(seconds: 60), (_) {
    debugPrint("[BLE BG] background tick");
  });

  // Auto-start BLE on service start.
  await bleHelper.scanAndConnect();
}

/// Parse Opus file format and return list of packets
/// Format: [OPUS][sample_rate][frame_size][len1][opus1][len2][opus2]...
Future<List<Uint8List>> _parseOpusFile() async {
  try {
    final ByteData data = await rootBundle.load('assets/ai.opus');
    final Uint8List bytes = data.buffer.asUint8List();
    
    // Read header (12 bytes)
    if (bytes.length < 12) {
      debugPrint('[OPUS] File too short');
      return [];
    }
    
    // Check magic string
    final magic = String.fromCharCodes(bytes.sublist(0, 4));
    if (magic != 'OPUS') {
      debugPrint('[OPUS] Invalid magic string: $magic');
      return [];
    }
    
    // Read sample rate and frame size (little-endian uint32)
    final sampleRate = bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24);
    final frameSize = bytes[8] | (bytes[9] << 8) | (bytes[10] << 16) | (bytes[11] << 24);
    
    debugPrint('[OPUS] Sample rate: $sampleRate, Frame size: $frameSize');
    
    // Parse frames
    List<Uint8List> packets = [];
    int offset = 12;
    
    while (offset + 2 <= bytes.length) {
      // Read frame length (2 bytes, little-endian)
      final frameLen = bytes[offset] | (bytes[offset + 1] << 8);
      offset += 2;
      
      if (offset + frameLen > bytes.length) {
        debugPrint('[OPUS] Incomplete frame at offset $offset');
        break;
      }
      
      // Extract opus data
      final opusData = bytes.sublist(offset, offset + frameLen);
      offset += frameLen;
      
      // Create packet: [length (2 bytes)] + [opus data]
      final packet = Uint8List(2 + opusData.length);
      packet[0] = opusData.length & 0xFF;
      packet[1] = (opusData.length >> 8) & 0xFF;
      packet.setRange(2, 2 + opusData.length, opusData);
      
      packets.add(packet);
    }
    
    debugPrint('[OPUS] Parsed ${packets.length} packets');
    return packets;
  } catch (e) {
    debugPrint('[OPUS] Error parsing file: $e');
    return [];
  }
}

/// Send Opus file in batches
Future<void> _sendOpusFile(SimpleBleHelper bleHelper, ServiceInstance service) async {
  try {
    if (!bleHelper.isConnected) {
      debugPrint('[OPUS] Not connected, cannot send');
      service.invoke('opus.status', {'status': 'error', 'message': 'Not connected'});
      return;
    }
    
    final rxCharacteristic = bleHelper.audioRxCharacteristic;
    final device = bleHelper.device;
    
    if (rxCharacteristic == null || device == null) {
      debugPrint('[OPUS] RX characteristic or device not available');
      service.invoke('opus.status', {'status': 'error', 'message': 'Characteristic not available'});
      return;
    }
    
    // Store non-null reference for use throughout function
    final rxChar = rxCharacteristic;
    final dev = device;
    
    // Get MTU
    int mtu = 23; // Default
    try {
      mtu = await dev.mtu.first.timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[OPUS] Could not get MTU, using default: $e');
    }
    final effectiveMtu = mtu - 3; // Subtract ATT overhead
    
    debugPrint('[OPUS] Starting send, MTU: $mtu, Effective: $effectiveMtu');
    service.invoke('opus.status', {'status': 'parsing'});
    
    // Parse opus file
    final packets = await _parseOpusFile();
    if (packets.isEmpty) {
      debugPrint('[OPUS] No packets to send');
      service.invoke('opus.status', {'status': 'error', 'message': 'No packets'});
      return;
    }
    
    debugPrint('[OPUS] Starting to send ${packets.length} packets (5 times)');
    service.invoke('opus.status', {
      'status': 'sending',
      'total': packets.length * 5,
      'totalIterations': 5,
    });
    
    // Batch packets up to MTU
    List<Uint8List> batches = [];
    Uint8List currentBatch = Uint8List(0);
    
    for (final packet in packets) {
      // If adding this packet would exceed MTU and we have a batch, enqueue current batch
      if (currentBatch.isNotEmpty && currentBatch.length + packet.length > effectiveMtu) {
        batches.add(currentBatch);
        currentBatch = Uint8List(0);
      }
      
      // Add packet to current batch
      if (currentBatch.isEmpty) {
        currentBatch = Uint8List.fromList(packet);
      } else {
        final newBatch = Uint8List(currentBatch.length + packet.length);
        newBatch.setRange(0, currentBatch.length, currentBatch);
        newBatch.setRange(currentBatch.length, currentBatch.length + packet.length, packet);
        currentBatch = newBatch;
      }
    }
    
    // Add final batch if not empty
    if (currentBatch.isNotEmpty) {
      batches.add(currentBatch);
    }
    
    debugPrint('[OPUS] Created ${batches.length} batches');
    
    const int repeatCount = 5;
    int totalSentBatches = 0;
    final totalBatches = batches.length * repeatCount;
    
    // Send the file 5 times
    for (int repeat = 0; repeat < repeatCount; repeat++) {
      debugPrint('[OPUS] Sending iteration ${repeat + 1}/$repeatCount');
      service.invoke('opus.status', {
        'status': 'sending',
        'iteration': repeat + 1,
        'totalIterations': repeatCount,
        'total': totalBatches,
      });
      
      // Send batches in bursts of 5 with delay
      for (int i = 0; i < batches.length; i++) {
        if (!bleHelper.isConnected) {
          debugPrint('[OPUS] Disconnected during send');
          break;
        }
        
        // Send batch
        try {
          await rxChar.write(batches[i], withoutResponse: true);
          totalSentBatches++;
          debugPrint('[OPUS] Iteration ${repeat + 1}: Sent batch ${i + 1}/${batches.length}: ${batches[i].length} bytes');
          service.invoke('opus.progress', {
            'sent': totalSentBatches,
            'total': totalBatches,
            'iteration': repeat + 1,
            'totalIterations': repeatCount,
          });
          
          // Wait 100ms between batches
          await Future.delayed(const Duration(milliseconds: 100));
          
          // After 5 batches, wait 500ms
          if ((i + 1) % 5 == 0 && i + 1 < batches.length) {
            debugPrint('[OPUS] Sent 5 batches, waiting 500ms...');
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          debugPrint('[OPUS] Error sending batch: $e');
          break;
        }
      }
      
      // Send EOF signal after each iteration (except the last one)
      if (repeat < repeatCount - 1) {
        if (bleHelper.isConnected) {
          try {
            await Future.delayed(const Duration(milliseconds: 100));
            const int signalEof = 0xFFFC;
            final eofPacket = Uint8List(2);
            eofPacket[0] = signalEof & 0xFF;
            eofPacket[1] = (signalEof >> 8) & 0xFF;
            await rxChar.write(eofPacket, withoutResponse: true);
            debugPrint('[OPUS] Sent EOF signal after iteration ${repeat + 1}');
            await Future.delayed(const Duration(milliseconds: 200));
          } catch (e) {
            debugPrint('[OPUS] Error sending EOF: $e');
          }
        }
      }
    }
    
    // Send final EOF signal after all iterations
    if (bleHelper.isConnected) {
      try {
        await Future.delayed(const Duration(milliseconds: 100));
        const int signalEof = 0xFFFC;
        final eofPacket = Uint8List(2);
        eofPacket[0] = signalEof & 0xFF;
        eofPacket[1] = (signalEof >> 8) & 0xFF;
        await rxChar.write(eofPacket, withoutResponse: true);
        debugPrint('[OPUS] Sent final EOF signal');
      } catch (e) {
        debugPrint('[OPUS] Error sending final EOF: $e');
      }
    }
    
    debugPrint('[OPUS] Finished sending: $totalSentBatches/$totalBatches batches across $repeatCount iterations');
    service.invoke('opus.status', {
      'status': 'done',
      'sent': totalSentBatches,
      'total': totalBatches,
      'iterations': repeatCount,
    });
  } catch (e) {
    debugPrint('[OPUS] Error in send: $e');
    service.invoke('opus.status', {'status': 'error', 'message': e.toString()});
  }
}

class _BackgroundBleListener implements IBleListener {
  final ServiceInstance service;
  final SimpleBleHelper bleHelper;
  final BackgroundSocketClient socketClient;
  int packetCount = 0;

  _BackgroundBleListener(this.service, this.bleHelper, this.socketClient);

  @override
  void onConnectionStateChanged(BleConnectionState state) {
    debugPrint("[BLE BG] Connection state: ${state.name}");
    service.invoke('ble.status', {'status': state.name});
  }

  @override
  void onAudioPacketReceived(Uint8List data) {
    packetCount++;
    debugPrint("[BLE BG] Packet $packetCount: ${data.length} bytes");
    service.invoke('ble.packet', {
      'count': packetCount,
      'size': data.length,
    });
    
    // Forward packet to socket server with index (will queue if not connected)
    socketClient.sendPacket(data, index: packetCount);
    if (socketClient.isConnected) {
      debugPrint("[BLE BG] Forwarded packet $packetCount (index: $packetCount) to socket");
    } else {
      debugPrint("[BLE BG] Socket not connected, queued packet $packetCount (queue: ${socketClient.queuedPacketCount})");
    }
    
    // Send ACK back to the device
    bleHelper.send(Uint8List.fromList([0x41, 0x43, 0x4B])); // "ACK" in ASCII
  }

  @override
  void onError(String error) {
    debugPrint("[BLE BG] Error: $error");
    service.invoke('ble.error', {'error': error});
  }
}

class BleBackgroundService {
  late FlutterBackgroundService _service;
  bool _isInitialized = false;

  final StreamController<String> _statusController = StreamController<String>.broadcast();
  final StreamController<int> _packetSizeController = StreamController<int>.broadcast();
  final StreamController<int> _packetCountController = StreamController<int>.broadcast();
  final StreamController<int> _queueSizeController = StreamController<int>.broadcast();
  final StreamController<Map<String, dynamic>> _opusStatusController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  Stream<int> get packetSizeStream => _packetSizeController.stream;
  Stream<int> get packetCountStream => _packetCountController.stream;
  Stream<int> get queueSizeStream => _queueSizeController.stream;
  Stream<Map<String, dynamic>> get opusStatusStream => _opusStatusController.stream;

  Future<void> init() async {
    if (_isInitialized) return;
    _service = FlutterBackgroundService();

    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: true,
        onStart: onStart,
        isForegroundMode: true,
        autoStartOnBoot: true,
      ),
    );

    _isInitialized = true;
  }

  Future<void> start() async {
    await _service.startService();

    _service.on('ble.status').listen((event) {
      final status = event?['status'] ?? 'unknown';
      _statusController.add(status);
    });

    _service.on('ble.packet').listen((event) {
      final count = event?['count'] ?? 0;
      final size = event?['size'] ?? 0;
      _packetCountController.add(count);
      _packetSizeController.add(size);
    });

    _service.on('ble.error').listen((event) {
      final error = event?['error'] ?? 'Unknown error';
      _statusController.add('error: $error');
    });

    _service.on('socket.queueSize').listen((event) {
      final count = event?['count'] ?? 0;
      _queueSizeController.add(count);
    });

    _service.on('opus.status').listen((event) {
      _opusStatusController.add(Map<String, dynamic>.from(event ?? {}));
    });

    _service.on('opus.progress').listen((event) {
      _opusStatusController.add(Map<String, dynamic>.from(event ?? {}));
    });
  }

  void startBle() {
    _service.invoke('ble.start');
  }

  void stopBle() {
    _service.invoke('ble.stop');
  }

  void stopService() {
    _service.invoke('stop');
  }

  void connectSocket(String url) {
    _service.invoke('socket.connect', {'url': url});
  }

  void disconnectSocket() {
    _service.invoke('socket.disconnect');
  }

  void sendOpusFile() {
    _service.invoke('send.opus');
  }

  void dispose() {
    _statusController.close();
    _packetSizeController.close();
    _packetCountController.close();
    _queueSizeController.close();
    _opusStatusController.close();
  }
}

class BleBackgroundApp extends StatelessWidget {
  const BleBackgroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Background Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BleBackgroundScreen(),
    );
  }
}

class BleBackgroundScreen extends StatefulWidget {
  const BleBackgroundScreen({super.key});

  @override
  State<BleBackgroundScreen> createState() => _BleBackgroundScreenState();
}

class _BleBackgroundScreenState extends State<BleBackgroundScreen>
    with WidgetsBindingObserver {
  final BleBackgroundService _bgService = BleBackgroundService();
  final TextEditingController _socketUrlController = TextEditingController(
    text: 'ws://192.168.0.44:8080'
  );

  String _bleStatus = 'scanning';
  int _packetCount = 0;
  int _lastPacketSize = 0;
  int _queuedPackets = 0;
  bool _serviceRunning = false;
  String _opusStatus = 'idle';
  String? _opusMessage;
  int _opusSent = 0;
  int _opusTotal = 0;
  int _opusIteration = 0;
  int _opusTotalIterations = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initService();
  }

  Future<void> _initService() async {
    await _bgService.init();
    await _bgService.start();

    _bgService.statusStream.listen((status) {
      setState(() {
        _bleStatus = status;
      });
    });

    _bgService.packetCountStream.listen((count) {
      setState(() {
        _packetCount = count;
      });
    });

    _bgService.packetSizeStream.listen((size) {
      setState(() {
        _lastPacketSize = size;
      });
    });

    _bgService.queueSizeStream.listen((count) {
      setState(() {
        _queuedPackets = count;
      });
    });

    _bgService.opusStatusStream.listen((status) {
      setState(() {
        _opusStatus = status['status'] ?? 'idle';
        _opusMessage = status['message'];
        _opusSent = status['sent'] ?? 0;
        _opusTotal = status['total'] ?? 0;
        _opusIteration = status['iteration'] ?? status['iterations'] ?? 0;
        _opusTotalIterations = status['totalIterations'] ?? status['iterations'] ?? 0;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("[BLE BG UI] App lifecycle state: $state");
  }

  @override
  void dispose() {
    _socketUrlController.dispose();
    _bgService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _startService() async {
    setState(() {
      _serviceRunning = true;
    });
    _bgService.startBle();
  }

  void _stopService() {
    _bgService.stopBle();
    setState(() {
      _serviceRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Background Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BLE Status: $_bleStatus'),
                    const SizedBox(height: 8),
                    Text('Packets: $_packetCount'),
                    const SizedBox(height: 4),
                    Text('Last packet size: $_lastPacketSize bytes'),
                    const SizedBox(height: 4),
                    Text('Service: ${_serviceRunning ? "Running" : "Stopped"}'),
                    if (_queuedPackets > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Queued packets: $_queuedPackets',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _socketUrlController,
              decoration: const InputDecoration(
                labelText: 'Socket Server URL',
                hintText: 'ws://192.168.0.44:8080',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                _bgService.connectSocket(_socketUrlController.text);
              },
              child: const Text('Connect Socket'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _serviceRunning ? _stopService : _startService,
              child: Text(_serviceRunning ? 'Stop BLE' : 'Start BLE'),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Opus File Sender',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text('Status: $_opusStatus'),
                    if (_opusTotalIterations > 0) ...[
                      const SizedBox(height: 4),
                      Text('Iteration: $_opusIteration/$_opusTotalIterations'),
                    ],
                    if (_opusMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _opusMessage!,
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                    if (_opusTotal > 0) ...[
                      const SizedBox(height: 4),
                      Text('Progress: $_opusSent/$_opusTotal batches'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _opusTotal > 0 ? _opusSent / _opusTotal : 0,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _bleStatus == 'connected' && _opusStatus != 'sending' && _opusStatus != 'parsing'
                  ? () => _bgService.sendOpusFile()
                  : null,
              child: const Text('Send ai.opus'),
            ),
          ],
        ),
      ),
    );
  }
}


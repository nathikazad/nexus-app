import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'background_service.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  await startBackgroundService(service);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BleBackgroundApp());
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
    text: 'ws://192.168.0.15:8080'
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
                hintText: 'ws://192.168.0.15:8080',
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
          ],
        ),
      ),
    );
  }
}


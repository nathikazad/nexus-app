import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'bg_ble_helper.dart';

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
  bleHelper.setListener(_BackgroundBleListener(service));
  await bleHelper.initialize();

  service.on('ble.start').listen((event) async {
    await bleHelper.scanAndConnect();
  });

  service.on('ble.stop').listen((event) async {
    await bleHelper.disconnect();
  });

  service.on('stop').listen((event) async {
    await bleHelper.disconnect();
    service.stopSelf();
  });

  // Keep a small tick so we know the isolate is still alive in background.
  Timer.periodic(const Duration(seconds: 60), (_) {
    debugPrint("[BLE BG] background tick");
  });

  // Auto-start BLE on service start.
  await bleHelper.scanAndConnect();
}

class _BackgroundBleListener implements IBleListener {
  final ServiceInstance service;
  int packetCount = 0;

  _BackgroundBleListener(this.service);

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

  Stream<String> get statusStream => _statusController.stream;
  Stream<int> get packetSizeStream => _packetSizeController.stream;
  Stream<int> get packetCountStream => _packetCountController.stream;

  Future<void> init() async {
    if (_isInitialized) return;
    _service = FlutterBackgroundService();

    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: false,
        onStart: onStart,
        isForegroundMode: true,
        autoStartOnBoot: false,
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

  void dispose() {
    _statusController.close();
    _packetSizeController.close();
    _packetCountController.close();
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

  String _bleStatus = 'disconnected';
  int _packetCount = 0;
  int _lastPacketSize = 0;
  bool _serviceRunning = false;

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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("[BLE BG UI] App lifecycle state: $state");
  }

  @override
  void dispose() {
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _serviceRunning ? _stopService : _startService,
              child: Text(_serviceRunning ? 'Stop BLE' : 'Start BLE'),
            ),
          ],
        ),
      ),
    );
  }
}


import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background_service.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  await BleBackgroundService.startBackgroundService(service);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create provider container and initialize the service
  final container = ProviderContainer();
  final bgService = container.read(bleBackgroundServiceProvider);
  await bgService.init(
    onStart: onStart,
    onIosBackground: onIosBackground,
  );
  await bgService.start();
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BleBackgroundApp(),
    ),
  );
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

class BleBackgroundScreen extends ConsumerStatefulWidget {
  const BleBackgroundScreen({super.key});

  @override
  ConsumerState<BleBackgroundScreen> createState() => _BleBackgroundScreenState();
}

class _BleBackgroundScreenState extends ConsumerState<BleBackgroundScreen>
    with WidgetsBindingObserver {
  final TextEditingController _socketUrlController = TextEditingController(
    text: 'ws://192.168.0.44:8002'
  );

  String _bleStatus = 'scanning';
  bool _serviceRunning = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initService();
  }

  Future<void> _initService() async {
    // Service is already initialized in main(), just set up listeners
    final bgService = ref.read(bleBackgroundServiceProvider);
    
    bgService.statusStream.listen((status) {
      setState(() {
        _bleStatus = status;
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
    // Note: Don't dispose the service here as it's managed by the provider
    // and may be used elsewhere. The provider will handle cleanup.
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _startService() async {
    final bgService = ref.read(bleBackgroundServiceProvider);
    setState(() {
      _serviceRunning = true;
    });
    bgService.startBle();
  }

  void _stopService() {
    final bgService = ref.read(bleBackgroundServiceProvider);
    bgService.stopBle();
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
                    Text('Service: ${_serviceRunning ? "Running" : "Stopped"}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _socketUrlController,
              decoration: const InputDecoration(
                labelText: 'Socket Server URL',
                hintText: 'ws://192.168.0.44:8002',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                final bgService = ref.read(bleBackgroundServiceProvider);
                bgService.connectSocket(_socketUrlController.text);
              },
              child: const Text('Connect Socket'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _serviceRunning ? _stopService : _startService,
              child: Text(_serviceRunning ? 'Stop BLE' : 'Start BLE'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final bgService = ref.read(bleBackgroundServiceProvider);
                final success = await bgService.writeHaptic(16);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success 
                        ? 'Haptic effect 16 triggered' 
                        : 'Failed to trigger haptic'),
                    ),
                  );
                }
              },
              child: const Text('Trigger Haptic (16)'),
            ),
          ],
        ),
      ),
    );
  }
}


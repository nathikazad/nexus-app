import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_dart/opus_dart.dart';
import 'dart:io';
import 'package:nx_db/nx_db.dart';
import 'router.dart';
import 'services/logging_service.dart';
import 'services/watch_bridge_service.dart';
import 'background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging service first (before any logging occurs)
  await LoggingService.instance.initialize();
  
  // Load environment variables
  await dotenv.load();
  
  // Initialize Opus library (only needed for mobile platforms)
  if (!kIsWeb) {
    initOpus(await opus_flutter.load());
  }
  
  // Request microphone permission (only needed for mobile platforms)
  if (!kIsWeb) {
    await Permission.microphone.request();
  }
  
  // Initialize Watch Bridge service (iOS only)
  if (!kIsWeb && Platform.isIOS) {
    await WatchBridgeService.instance.initialize();
  }
  
  // Create provider container and initialize the background service
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
      child: const MyApp(),
    ),
  );
}

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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final user = next.value!;
        final urls = resolve(user.preset);
        ref.read(bleBackgroundServiceProvider).connectSocket(urls.sockWs);
      }
    });

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Nexus Voice Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

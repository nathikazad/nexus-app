import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/services/hardware_service/hardware_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_dart/opus_dart.dart';
import 'dart:io';
import 'router.dart';
import 'services/openai_service.dart';
import 'services/logging_service.dart';
import 'services/background_service.dart';

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
  
  // Initialize background service (only needed for mobile platforms)
  if (!kIsWeb) {
    final backgroundService = BackgroundService();
    await backgroundService.init();
  }
  
  // Initialize BLE service (only needed for mobile platforms)
  if (!kIsWeb) {
    await HardwareService.instance.initialize();
  }
  
  // OpenAI service is now managed by openAIServiceProvider
  // It will connect when user is authenticated and disconnect when unauthenticated
  
  // Start background service when BLE is connected (iOS needs this for background operation)
  if (!kIsWeb && Platform.isIOS) {
    HardwareService.instance.connectionStateStream?.listen((isConnected) async {
      if (isConnected) {
        final backgroundService = BackgroundService();
        await backgroundService.ensureRunning();
      }
    });
  }
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    // Watch openAIServiceProvider to manage its lifecycle based on auth status
    // This ensures OpenAI connects when authenticated and disconnects when unauthenticated
    ref.watch(openAIServiceProvider);
    
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

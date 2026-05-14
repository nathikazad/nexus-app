import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_dart/opus_dart.dart';
import 'dart:io';
import 'package:nexus_voice_assistant/app.dart';
import 'package:nexus_voice_assistant/core/logging/logging_service.dart';
import 'package:nexus_voice_assistant/data/background/background_service.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/data/watch/watch_bridge_service.dart';
import 'package:nx_db/riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LoggingService.instance.initialize();

  if (!kIsWeb) {
    initOpus(await opus_flutter.load());
  }

  if (!kIsWeb) {
    await Permission.microphone.request();
    await Permission.locationWhenInUse.request();
    await Permission.locationAlways.request();
  }

  if (!kIsWeb && Platform.isIOS) {
    await WatchBridgeService.instance.initialize();
  }

  final container = ProviderContainer(
    overrides: [dbAuditSourceKindProvider.overrideWithValue('nx_main')],
  );
  final bgService = container.read(bleBackgroundServiceProvider);
  await bgService.init(
    onStart: onStart,
    onIosBackground: onIosBackground,
  );
  await bgService.start();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NexusVoiceAssistantApp(),
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

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

enum BackgroundServiceStatus {
  initiated,
  running,
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  // Watchdog timer to keep service alive
  var pongAt = DateTime.now();
  service.on('pong').listen((event) async {
    pongAt = DateTime.now();
  });
  
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (pongAt.isBefore(DateTime.now().subtract(const Duration(seconds: 15)))) {
      // No pong received, stop service
      service.stopSelf();
      return;
    }
    service.invoke("ui.ping");
  });
}

class BackgroundService {
  late FlutterBackgroundService _service;
  BackgroundServiceStatus? _status;

  BackgroundServiceStatus? get status => _status;

  Future<void> init() async {
    _service = FlutterBackgroundService();
    _status = BackgroundServiceStatus.initiated;

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
        foregroundServiceTypes: [AndroidForegroundType.microphone],
      ),
    );

    _status = BackgroundServiceStatus.initiated;
  }

  Future<void> ensureRunning() async {
    await init();
    await start();
  }

  Future<void> start() async {
    _service.startService();

    // status
    if (await _service.isRunning()) {
      _status = BackgroundServiceStatus.running;
    }

    // heartbeat
    _service.on('ui.ping').listen((event) {
      _service.invoke("pong");
    });
  }

  void stop() {
    debugPrint("invoke stop");
    _service.invoke("stop");
  }
}


import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'bg_ble_client.dart';
import 'bg_socket_client.dart';


/// Listener that forwards Opus batches to BLE helper
class _OpusBatchListener implements IOpusBatchListener {
  final BleClient bleHelper;
  
  _OpusBatchListener(this.bleHelper);
  
  @override
  Future<void> sendBatch(Uint8List batch) async {
    await bleHelper.sendBatch(batch);
  }
  
  @override
  Future<void> sendEof() async {
    await bleHelper.sendEof();
  }
}

class _BackgroundBleListener implements IBleListener {
  final ServiceInstance service;
  final BleClient bleHelper;
  final SocketClient socketClient;
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


/// Start the background service (called from onStart entry point)
Future<void> startBackgroundService(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final bleClient = BleClient();
  final socketClient = SocketClient();
  
  // Configure socket URL (default, can be changed via event)
  const defaultSocketUrl = 'ws://192.168.0.44:8080';
  await socketClient.connect(defaultSocketUrl);
  
  bleClient.setListener(_BackgroundBleListener(service, bleClient, socketClient));
  await bleClient.initialize();

  final effectiveMtu = await bleClient.getEffectiveMtu();
  socketClient.setMtu(_OpusBatchListener(bleClient), effectiveMtu);

  service.on('ble.start').listen((event) async {
    await bleClient.scanAndConnect();
  });

  service.on('ble.stop').listen((event) async {
    await bleClient.disconnect();
  });

  service.on('stop').listen((event) async {
    await bleClient.disconnect();
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

  // Keep a small tick so we know the isolate is still alive in background.
  Timer.periodic(const Duration(seconds: 60), (_) {
    debugPrint("[BLE BG] background tick");
  });

  // Auto-start BLE on service start.
  await bleClient.scanAndConnect();
}

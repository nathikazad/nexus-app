import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'bg_ble_client.dart';
import 'bg_socket_client.dart';


/// Start the background service (called from onStart entry point)
Future<void> startBackgroundService(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // ============================================================================
  // 1. INITIALIZATION
  // ============================================================================
  
  final bleClient = BleClient();
  final socketClient = SocketClient();
  const defaultSocketUrl = 'ws://192.168.0.15:8080';
  
  await socketClient.connect(defaultSocketUrl);
  
  // ============================================================================
  // 2. BLE CONFIGURATION
  // ============================================================================
  
  int packetCount = 0;
  
  bleClient.onConnectionStateChanged = (state) {
    debugPrint("[BLE BG] Connection state: ${state.name}");
    service.invoke('ble.status', {'status': state.name});
  };
  
  bleClient.onAudioPacketReceived = (data) {
    packetCount++;
    debugPrint("[BLE BG] Packet $packetCount: ${data.length} bytes");
    service.invoke('ble.packet', {
      'count': packetCount,
      'size': data.length,
    });
    
    // Forward packet to socket server with index (will queue if not connected)
    socketClient.sendPacket(data, index: packetCount);
    // Send ACK back to the device
    bleClient.send(Uint8List.fromList([0x41, 0x43, 0x4B])); // "ACK" in ASCII
  };
  
  bleClient.onError = (error) {
    debugPrint("[BLE BG] Error: $error");
    service.invoke('ble.error', {'error': error});
  };
  
  await bleClient.initialize();
  
  // ============================================================================
  // 3. SOCKET CONFIGURATION
  // ============================================================================
  
  // Forward packets from server to BLE
  socketClient.onPacketFromServer = (packet) => bleClient.send(packet);
  
  // ============================================================================
  // 4. SERVICE EVENT HANDLERS
  // ============================================================================
  
  // BLE control events
  service.on('ble.start').listen((event) async {
    await bleClient.scanAndConnect();
  });
  
  service.on('ble.stop').listen((event) async {
    await bleClient.disconnect();
  });
  
  // Socket control events
  service.on('socket.connect').listen((event) async {
    final url = event?['url'] ?? defaultSocketUrl;
    await socketClient.connect(url);
  });
  
  service.on('socket.disconnect').listen((event) async {
    await socketClient.disconnect();
  });
  
  // Service lifecycle events
  service.on('stop').listen((event) async {
    await bleClient.disconnect();
    await socketClient.disconnect();
    service.stopSelf();
  });
  
  // ============================================================================
  // 5. BACKGROUND MAINTENANCE
  // ============================================================================
  
  Timer.periodic(const Duration(seconds: 60), (_) {
    debugPrint("[BLE BG] background tick");
  });
  
  // ============================================================================
  // 6. STARTUP
  // ============================================================================
  
  await bleClient.scanAndConnect();
}

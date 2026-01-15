import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_audio_transport.dart';
import 'ble_file_transport.dart';
import 'ble_service.dart';



class BLEConnectResult {
  final bool success;
  final StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  BLEConnectResult(this.success, this.connectionSubscription);
}

/// BLE connection utilities
class BLEConnector {
  static Future<BLEConnectResult> connectAndSetup({
    required BluetoothDevice device,
    required BLEAudioTransport audioTransport,
    required BLEFileTransport fileTransport,
    required void Function(BluetoothCharacteristic?) setBatteryCharacteristic,
    required void Function(BluetoothCharacteristic?) setRtcCharacteristic,
    required void Function(BluetoothCharacteristic?) setHapticCharacteristic,
    required void Function(BluetoothCharacteristic?) setDeviceNameCharacteristic,
    required void Function(BluetoothCharacteristic?) setFileTxCharacteristic,
    required void Function(BluetoothCharacteristic?) setFileRxCharacteristic,
    required void Function(BluetoothCharacteristic?) setFileCtrlCharacteristic,
    required void Function(bool) setConnected,
    required void Function(int) updateMtu,
    required void Function(bool) emitConnectionState,
    required Future<void> Function() onDisconnected,
    required bool Function() shouldReinitialize,
    required Future<void> Function() reinitializeAfterRestore,
  }) async {
    try {
      debugPrint('Connecting to device...');

      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: true,
        mtu: null,
      );

      await device.connectionState.firstWhere(
        (state) => state == BluetoothConnectionState.connected,
        orElse: () => BluetoothConnectionState.disconnected,
      );

      setConnected(true);
      emitConnectionState(true);
      debugPrint('Connected!');

      final targetService = await _discoverTargetService(device, BLEService.serviceUuid);
      if (targetService == null) {
        debugPrint('Service not found: ${BLEService.serviceUuid}');
        await device.disconnect();
        setConnected(false);
        emitConnectionState(false);
        return BLEConnectResult(false, null);
      }

      // Initialize audio transport
      if (!await audioTransport.initializeAudioTransportCharacteristics(
        targetService,
        BLEService.audioTxCharacteristicUuid,
        BLEService.audioRxCharacteristicUuid,
      )) {
        debugPrint('Failed to initialize audio transport');
      }

      debugPrint('Initializing file transport...');
      if (!await fileTransport.initializeFileTransport(
        targetService,
        BLEService.fileTxCharacteristicUuid,
        BLEService.fileRxCharacteristicUuid,
        BLEService.fileCtrlCharacteristicUuid,
      )) {
        debugPrint('Failed to initialize file transport');
      }

      _assignCharacteristics(
        targetService,
        setBatteryCharacteristic,
        setRtcCharacteristic,
        setHapticCharacteristic,
        setDeviceNameCharacteristic,
        setFileTxCharacteristic,
        setFileRxCharacteristic,
        setFileCtrlCharacteristic,
      );

      try {
        final mtu = await device.mtu.first;
        updateMtu(mtu);
        debugPrint('MTU size: $mtu bytes');
      } catch (e) {
        debugPrint('Error getting MTU: $e');
      }

      device.mtu.listen((mtu) {
        updateMtu(mtu);
        debugPrint('MTU updated: $mtu bytes');
      });

      final subscription = device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('Device disconnected');
          setConnected(false);
          emitConnectionState(false);
          await onDisconnected();
        } else if (state == BluetoothConnectionState.connected) {
          setConnected(true);
          emitConnectionState(true);
          if (shouldReinitialize()) {
            debugPrint('Connection restored, reinitializing characteristics...');
            await reinitializeAfterRestore();
          }
        }
      });

      return BLEConnectResult(true, subscription);
    } catch (e) {
      debugPrint('Error connecting: $e');
      setConnected(false);
      emitConnectionState(false);
      return BLEConnectResult(false, null);
    }
  }

  static Future<void> reinitializeAfterRestore({
    required BluetoothDevice device,
    required BLEAudioTransport audioTransport,
    required BLEFileTransport fileTransport,
    required void Function(BluetoothCharacteristic?) setBatteryCharacteristic,
    required void Function(BluetoothCharacteristic?) setRtcCharacteristic,
    required void Function(BluetoothCharacteristic?) setHapticCharacteristic,
    required void Function(BluetoothCharacteristic?) setDeviceNameCharacteristic,
    required void Function(BluetoothCharacteristic?) setFileTxCharacteristic,
    required void Function(BluetoothCharacteristic?) setFileRxCharacteristic,
    required void Function(BluetoothCharacteristic?) setFileCtrlCharacteristic,
  }) async {
    try {
      await device.connectionState.firstWhere(
        (state) => state == BluetoothConnectionState.connected,
        orElse: () => BluetoothConnectionState.disconnected,
      );

      debugPrint('Reinitializing characteristics after restore...');
      final targetService = await _discoverTargetService(device, BLEService.serviceUuid);
      if (targetService == null) {
        debugPrint('Service not found after restore: ${BLEService.serviceUuid}');
        return;
      }

      if (!await audioTransport.initializeAudioTransportCharacteristics(
        targetService,
        BLEService.audioTxCharacteristicUuid,
        BLEService.audioRxCharacteristicUuid,
      )) {
        debugPrint('Failed to initialize audio TX/RX characteristics after restore');
        return;
      }

      await fileTransport.initializeFileTransport(
        targetService,
        BLEService.fileTxCharacteristicUuid,
        BLEService.fileRxCharacteristicUuid,
        BLEService.fileCtrlCharacteristicUuid,
      );

      _assignCharacteristics(
        targetService,
        setBatteryCharacteristic,
        setRtcCharacteristic,
        setHapticCharacteristic,
        setDeviceNameCharacteristic,
        setFileTxCharacteristic,
        setFileRxCharacteristic,
        setFileCtrlCharacteristic,
      );

      debugPrint('Successfully reinitialized after restore');
    } catch (e) {
      debugPrint('Error reinitializing after restore: $e');
    }
  }

  static Future<BluetoothService?> _discoverTargetService(
    BluetoothDevice device,
    String serviceUuid,
  ) async {
    final services = await device.discoverServices();
    debugPrint('Discovered ${services.length} services');
    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        return service;
      }
    }
    return null;
  }

  static void _assignCharacteristics(
    BluetoothService service,
    void Function(BluetoothCharacteristic?) setBatteryCharacteristic,
    void Function(BluetoothCharacteristic?) setRtcCharacteristic,
    void Function(BluetoothCharacteristic?) setHapticCharacteristic,
    void Function(BluetoothCharacteristic?) setDeviceNameCharacteristic,
    void Function(BluetoothCharacteristic?) setFileTxCharacteristic,
    void Function(BluetoothCharacteristic?) setFileRxCharacteristic,
    void Function(BluetoothCharacteristic?) setFileCtrlCharacteristic,
  ) {
    for (BluetoothCharacteristic char in service.characteristics) {
      final uuid = char.uuid.toString().toLowerCase();
      if (uuid == BLEService.batteryCharacteristicUuid.toLowerCase()) {
        setBatteryCharacteristic(char);
        debugPrint('Found Battery characteristic');
      } else if (uuid == BLEService.rtcCharacteristicUuid.toLowerCase()) {
        setRtcCharacteristic(char);
        debugPrint('Found RTC characteristic');
      } else if (uuid == BLEService.hapticCharacteristicUuid.toLowerCase()) {
        setHapticCharacteristic(char);
        debugPrint('Found Haptic characteristic');
      } else if (uuid == BLEService.deviceNameCharacteristicUuid.toLowerCase()) {
        setDeviceNameCharacteristic(char);
        debugPrint('Found Device Name characteristic');
      } else if (uuid == BLEService.fileTxCharacteristicUuid.toLowerCase()) {
        setFileTxCharacteristic(char);
        debugPrint('Found File TX characteristic');
      } else if (uuid == BLEService.fileRxCharacteristicUuid.toLowerCase()) {
        setFileRxCharacteristic(char);
        debugPrint('Found File RX characteristic');
      } else if (uuid == BLEService.fileCtrlCharacteristicUuid.toLowerCase()) {
        setFileCtrlCharacteristic(char);
        debugPrint('Found File CTRL characteristic');
      }
    }
  }
}


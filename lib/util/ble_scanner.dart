import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE scanning utilities
class BLEScanner {
  static bool _isScanning = false;

  static bool get isScanning => _isScanning;

  /// Scan for devices and return a stream of scan results
  static Stream<List<ScanResult>> scanForDevices({
    required String serviceUuid,
    Duration? timeout,
  }) async* {
    if (_isScanning) {
      debugPrint('Scan already in progress');
      return;
    }

    try {
      _isScanning = true;
      debugPrint('Scanning for devices with service UUID $serviceUuid...');

      // Stop any existing scan first
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        // Ignore errors if scan wasn't running
      }

      // Convert service UUID string to Guid for filtering
      final serviceGuid = Guid(serviceUuid);

      // Start scanning with service UUID filter
      await FlutterBluePlus.startScan(
        withServices: [serviceGuid],
        timeout: timeout ?? const Duration(seconds: 10),
      );

      // Yield scan results as they come in
      await for (final results in FlutterBluePlus.scanResults) {
        final filteredResults = results.toList();
        if (filteredResults.isNotEmpty) {
          yield filteredResults;
        }
      }
    } catch (e) {
      debugPrint('Error scanning for devices: $e');
      yield [];
    } finally {
      _isScanning = false;
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        // Ignore errors
      }
    }
  }

  /// Scan indefinitely for a single device matching the service UUID
  static Future<BluetoothDevice?> scanForSingleDevice({
    required String serviceUuid,
  }) async {
    if (_isScanning) {
      debugPrint('Scan already in progress');
      return null;
    }

    try {
      _isScanning = true;
      debugPrint('Scanning indefinitely for service UUID $serviceUuid...');

      // Stop any existing scan first
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        // Ignore errors if scan wasn't running
      }

      // Convert service UUID string to Guid for filtering
      final serviceGuid = Guid(serviceUuid);

      // Start scanning indefinitely (no timeout) with service UUID filter
      await FlutterBluePlus.startScan(
        withServices: [serviceGuid],
      );

      // Listen for scan results
      StreamSubscription<List<ScanResult>>? scanSubscription;
      final completer = Completer<BluetoothDevice?>();
      bool deviceFound = false;

      scanSubscription = FlutterBluePlus.scanResults.listen(
        (List<ScanResult> results) {
          if (deviceFound) return;
          for (ScanResult result in results) {
            if (deviceFound) break;

            final name = result.advertisementData.advName.isNotEmpty
                ? result.advertisementData.advName
                : (result.device.platformName.isNotEmpty
                    ? result.device.platformName
                    : result.device.advName);

            debugPrint('Found device with service UUID: $name at ${result.device.remoteId}');
            deviceFound = true;
            scanSubscription?.cancel();
            FlutterBluePlus.stopScan();
            _isScanning = false;
            if (!completer.isCompleted) {
              completer.complete(result.device);
            }
            return;
          }
        },
        onError: (error) {
          debugPrint('Scan error: $error');
        },
      );

      return await completer.future;
    } catch (e) {
      _isScanning = false;
      debugPrint('Error scanning: $e');
      await FlutterBluePlus.stopScan();
      return null;
    }
  }

  static void stopScan() {
    _isScanning = false;
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore errors
    }
  }
}


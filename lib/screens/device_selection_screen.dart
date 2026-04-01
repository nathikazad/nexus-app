import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/bg_ble_client.dart';
import 'package:nexus_voice_assistant/services/hardware_service/hardware_service.dart';
import 'package:nexus_voice_assistant/services/logging_service.dart';

class DeviceSelectionScreen extends ConsumerStatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  ConsumerState<DeviceSelectionScreen> createState() =>
      _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends ConsumerState<DeviceSelectionScreen> {
  final List<ScanResult> _devices = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  String? _selectedDeviceId;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    try {
      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first;

      final serviceGuid = Guid(BleConstants.serviceUuid);

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          if (!mounted) return;
          final seen = <String>{};
          final next = <ScanResult>[];
          for (final r in results) {
            final id = r.device.remoteId.str;
            if (seen.contains(id)) continue;
            seen.add(id);
            next.add(r);
          }
          setState(() {
            _devices
              ..clear()
              ..addAll(next);
          });
        },
        onError: (e) {
          LoggingService.instance.log('Scan error: $e');
        },
      );

      await FlutterBluePlus.startScan(withServices: [serviceGuid]);
    } catch (e) {
      LoggingService.instance.log('Start scan failed: $e');
      if (mounted) {
        setState(() => _isScanning = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  String _formatDeviceName(ScanResult result) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : result.device.advName;

    if (name.startsWith('Nexus-')) {
      return name;
    }

    final macStr = result.device.remoteId.toString();
    final macParts = macStr.replaceAll(':', '').replaceAll('-', '').toUpperCase();
    if (macParts.length >= 5) {
      final last5 = macParts.substring(macParts.length - 5);
      return 'Nexus-$last5';
    }

    return name.isNotEmpty ? name : 'Unknown Device';
  }

  Future<void> _connectToDevice(ScanResult result) async {
    if (_isConnecting) return;

    setState(() {
      _selectedDeviceId = result.device.remoteId.str;
      _isConnecting = true;
    });

    try {
      _scanSubscription?.cancel();
      await FlutterBluePlus.stopScan();

      final hw = ref.read(hardwareServiceProvider);
      await hw.savePairedRemoteIdAndConnect(result.device.remoteId.str);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      LoggingService.instance.log('Error saving paired device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() {
          _isConnecting = false;
          _selectedDeviceId = null;
        });
        await _startScan();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Nexus device'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startScan,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Choose the physical unit for this phone. Only this device will connect.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          if (_isScanning && _devices.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Scanning for Nexus devices...'),
                  ],
                ),
              ),
            )
          else if (_devices.isEmpty && !_isScanning)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No Nexus devices found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Scan again'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final result = _devices[index];
                  final deviceId = result.device.remoteId.str;
                  final isSelected = _selectedDeviceId == deviceId;
                  final isConnecting = _isConnecting && isSelected;

                  return ListTile(
                    leading: Icon(
                      Icons.bluetooth,
                      color: isConnecting ? Colors.blue : Colors.grey[600],
                    ),
                    title: Text(
                      _formatDeviceName(result),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${result.device.remoteId}'),
                        Text('Signal: ${result.rssi} dBm'),
                      ],
                    ),
                    trailing: isConnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: isConnecting ? null : () => _connectToDevice(result),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

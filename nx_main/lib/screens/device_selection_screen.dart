import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_voice_assistant/app_theme.dart';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
              icon: const Icon(Icons.refresh_rounded, color: AppColors.gray900),
              onPressed: _startScan,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Nexus device',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the physical unit for this phone. Only this device will connect.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.45,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final result = _devices[index];
                  final deviceId = result.device.remoteId.str;
                  final isSelected = _selectedDeviceId == deviceId;
                  final isConnecting = _isConnecting && isSelected;
                  final name = _formatDeviceName(result);

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: isConnecting ? null : () => _connectToDevice(result),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isConnecting
                                ? AppColors.orange600
                                : AppColors.gray200,
                            width: isConnecting ? 2 : 1,
                          ),
                          color: isConnecting
                              ? AppColors.orange50
                              : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isConnecting
                                    ? AppColors.orange50
                                    : AppColors.gray100,
                                shape: BoxShape.circle,
                              ),
                              child: isConnecting
                                  ? Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.orange600,
                                      ),
                                    )
                                  : Icon(
                                      Icons.bluetooth_rounded,
                                      color: AppColors.gray600,
                                      size: 22,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.gray900,
                                ),
                              ),
                            ),
                            if (isConnecting)
                              Text(
                                'Connecting...',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.orange600,
                                ),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.signal_cellular_alt,
                                    size: 16,
                                    color: AppColors.gray400,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${result.rssi} dBm',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.gray400,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

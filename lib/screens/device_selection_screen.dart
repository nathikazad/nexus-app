import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';

class DeviceSelectionScreen extends StatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  State<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  final BLEService _bleService = BLEService.instance;
  List<ScanResult> _devices = [];
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
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _startScan() {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _devices = [];
    });

    _scanSubscription = _bleService.scanForDevices(timeout: const Duration(seconds: 10)).listen(
      (results) {
        // Update device list, avoiding duplicates
        final existingIds = _devices.map((d) => d.device.remoteId.toString()).toSet();
        final newDevices = results.where((r) => !existingIds.contains(r.device.remoteId.toString())).toList();
        
        if (mounted) {
          setState(() {
            _devices.addAll(newDevices);
            // Sort by RSSI (strongest signal first)
            _devices.sort((a, b) => b.rssi.compareTo(a.rssi));
          });
        }
      },
      onError: (error) {
        debugPrint('Scan error: $error');
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      },
    );
  }

  String _formatDeviceName(ScanResult result) {
    final name = result.device.platformName.isNotEmpty 
        ? result.device.platformName 
        : result.device.advName;
    
    // If name starts with "Nexus-", return it as-is
    if (name.startsWith('Nexus-')) {
      return name;
    }
    
    // Otherwise, format from MAC address
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
      _selectedDeviceId = result.device.remoteId.toString();
      _isConnecting = true;
    });

    try {
      // Stop scanning
      _scanSubscription?.cancel();
      await FlutterBluePlus.stopScan();

      // Connect to device
      final success = await _bleService.connectToDevice(result.device);
      
      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true); // Return true to indicate successful connection
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to connect to device')),
          );
          setState(() {
            _isConnecting = false;
            _selectedDeviceId = null;
          });
          // Restart scan
          _startScan();
        }
      }
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting: $e')),
        );
        setState(() {
          _isConnecting = false;
          _selectedDeviceId = null;
        });
        // Restart scan
        _startScan();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Device'),
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
          if (_isScanning && _devices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Scanning for devices...'),
                  ],
                ),
              ),
            )
          else if (_devices.isEmpty && !_isScanning)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No devices found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan Again'),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final result = _devices[index];
                  final deviceId = result.device.remoteId.toString();
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
                        Text('MAC: ${result.device.remoteId}'),
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


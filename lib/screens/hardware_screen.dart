import 'dart:async';
import 'package:flutter/material.dart';
import '../services/hardware_service.dart';
import '../services/ble_service.dart';

class HardwareScreen extends StatefulWidget {
  const HardwareScreen({super.key});

  @override
  State<HardwareScreen> createState() => _HardwareScreenState();
}

class _HardwareScreenState extends State<HardwareScreen> {
  final HardwareService _hardwareService = HardwareService.instance;
  final BLEService _bleService = BLEService.instance;
  
  int? _batteryPercentage;
  double? _voltage;
  bool _isConnected = false;
  
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<int>? _batterySubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _readBatteryData();
    // Refresh battery data every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _readBatteryData();
    });
  }

  void _setupListeners() {
    // Listen to connection state
    _connectionSubscription = _bleService.connectionStateStream?.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
          if (!isConnected) {
            _batteryPercentage = null;
            _voltage = null;
          }
        });
      }
    });
    
    // Listen to battery updates
    _batterySubscription = _hardwareService.batteryStream?.listen((battery) {
      if (mounted) {
        setState(() {
          _batteryPercentage = battery;
        });
      }
    });
    
    // Set initial connection state
    setState(() {
      _isConnected = _bleService.isConnected;
    });
  }

  Future<void> _readBatteryData() async {
    if (!_isConnected) {
      return;
    }
    
    final batteryCharacteristic = _bleService.batteryCharacteristic;
    if (batteryCharacteristic == null) {
      return;
    }

    try {
      final data = await batteryCharacteristic.read();
      if (data.length >= 3) {
        // Format: [voltage_msb, voltage_lsb, soc_percent]
        final voltageMsb = data[0];
        final voltageLsb = data[1];
        final socPercent = data[2];
        
        // Calculate voltage: (msb << 8) | lsb, then divide by 100 to get volts
        final voltageRaw = (voltageMsb << 8) | voltageLsb;
        final voltage = voltageRaw / 100.0;
        
        if (mounted) {
          setState(() {
            _batteryPercentage = socPercent;
            _voltage = voltage;
          });
        }
      }
    } catch (e) {
      debugPrint('Error reading battery data: $e');
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _batterySubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Status'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Battery percentage
            if (_isConnected && _batteryPercentage != null) ...[
              Icon(
                Icons.battery_std,
                size: 64,
                color: _getBatteryColor(_batteryPercentage!),
              ),
              const SizedBox(height: 16),
              Text(
                'Battery',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_batteryPercentage%',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getBatteryColor(_batteryPercentage!),
                ),
              ),
            ] else ...[
              Icon(
                Icons.battery_unknown,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Battery',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '--',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
            
            const SizedBox(height: 48),
            
            // Voltage reading
            if (_isConnected && _voltage != null) ...[
              Icon(
                Icons.flash_on,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'Voltage',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_voltage!.toStringAsFixed(2)} V',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ] else ...[
              Icon(
                Icons.flash_off,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Voltage',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '-- V',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
            
            if (!_isConnected) ...[
              const SizedBox(height: 48),
              Text(
                'Not connected to device',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Color _getBatteryColor(int percentage) {
    if (percentage >= 50) {
      return Colors.green;
    } else if (percentage >= 20) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}


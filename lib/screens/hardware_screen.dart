import 'dart:async';
import 'package:flutter/material.dart';
import '../services/hardware_service.dart';
import '../services/ble_service.dart';
import 'device_selection_screen.dart';

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
  bool? _isCharging;
  String? _rtcTimeDisplay;
  String? _rtcTimezone;
  bool _isConnected = false;
  bool _isSettingRTC = false;
  bool _isPulsingHaptic = false;
  
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<BatteryData>? _batterySubscription;
  Timer? _batteryRefreshTimer;
  Timer? _rtcRefreshTimer;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _startRefreshTimers();
  }

  void _startRefreshTimers() {
    // Read immediately
    _hardwareService.readBattery();
    _readRTCData();
    
    // Refresh battery and RTC data every 1 second
    _batteryRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _hardwareService.readBattery();
    });
    
    _rtcRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _readRTCData();
    });
  }

  void _stopRefreshTimers() {
    _batteryRefreshTimer?.cancel();
    _batteryRefreshTimer = null;
    _rtcRefreshTimer?.cancel();
    _rtcRefreshTimer = null;
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
            _isCharging = null;
            _rtcTimeDisplay = null;
            _rtcTimezone = null;
            _stopRefreshTimers();
          } else {
            // Restart timers when connected
            _startRefreshTimers();
          }
        });
      }
    });
    
    // Listen to battery updates
    _batterySubscription = _hardwareService.batteryStream?.listen((batteryData) {
      if (mounted) {
        setState(() {
          _batteryPercentage = batteryData.percentage;
          _voltage = batteryData.voltage;
          _isCharging = batteryData.isCharging;
        });
      }
    });
    
    // Set initial connection state
    setState(() {
      _isConnected = _bleService.isConnected;
    });
  }


  Future<void> _readRTCData() async {
    if (!_isConnected) {
      return;
    }

    try {
      final rtcTime = await _hardwareService.readRTC();
      if (mounted && rtcTime != null) {
        setState(() {
          _rtcTimeDisplay = rtcTime.toDisplayString();
          _rtcTimezone = rtcTime.getTimezoneString();
        });
      }
    } catch (e) {
      debugPrint('Error reading RTC data: $e');
    }
  }

  Future<void> _setRTCTime() async {
    if (!_isConnected || _isSettingRTC) {
      return;
    }

    setState(() {
      _isSettingRTC = true;
    });

    try {
      final success = await _hardwareService.setRTCTimeNow();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('RTC time set successfully')),
          );
          // Refresh RTC display
          await _readRTCData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to set RTC time')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting RTC time: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingRTC = false;
        });
      }
    }
  }

  Future<void> _pulseHaptic() async {
    if (!_isConnected || _isPulsingHaptic) {
      return;
    }

    setState(() {
      _isPulsingHaptic = true;
    });

    try {
      final success = await _hardwareService.triggerHapticPulse();
      if (mounted) {
        if (success) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Haptic pulse triggered')),
          // );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to trigger haptic pulse')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error triggering haptic pulse: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPulsingHaptic = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _stopRefreshTimers();
    _connectionSubscription?.cancel();
    _batterySubscription?.cancel();
    super.dispose();
  }

  Future<void> _selectDevice() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const DeviceSelectionScreen()),
    );
    
    if (result == true && mounted) {
      // Device connected successfully, refresh UI
      setState(() {
        _isConnected = _bleService.isConnected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = _bleService.deviceName;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Status'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_searching),
            onPressed: _selectDevice,
            tooltip: 'Select Device',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Device name
            if (deviceName != null) ...[
              Text(
                'Device',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                deviceName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),
            ],
            // Battery percentage
            Text(
              'Battery',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _isConnected && _batteryPercentage != null
                      ? '$_batteryPercentage%'
                      : '--',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isConnected && _batteryPercentage != null
                        ? _getBatteryColor(_batteryPercentage!)
                        : Colors.grey,
                  ),
                ),
                if (_isConnected && _isCharging == true) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.battery_charging_full,
                    color: Colors.green,
                    size: 32,
                  ),
                ],
              ],
            ),
            if (_isConnected && _isCharging != null) ...[
              const SizedBox(height: 4),
              Text(
                _isCharging! ? 'Charging' : 'Not Charging',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _isCharging! ? Colors.green : Colors.grey[600],
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // Voltage reading
            Text(
              'Voltage',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isConnected && _voltage != null
                  ? '${_voltage!.toStringAsFixed(2)} V'
                  : '-- V',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _isConnected && _voltage != null
                    ? Colors.orange
                    : Colors.grey,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // RTC Time
            Text(
              'RTC Time',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isConnected && _rtcTimeDisplay != null ? _rtcTimeDisplay! : '--',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _isConnected && _rtcTimeDisplay != null
                    ? Colors.blue
                    : Colors.grey,
              ),
            ),
            if (_isConnected && _rtcTimezone != null) ...[
              const SizedBox(height: 4),
              Text(
                _rtcTimezone!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (_isConnected && _rtcTimeDisplay != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isSettingRTC ? null : _setRTCTime,
                icon: _isSettingRTC
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.update),
                label: Text(_isSettingRTC ? 'Setting...' : 'Set from System Time'),
              ),
            ],
            
            if (_isConnected) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isPulsingHaptic ? null : _pulseHaptic,
                icon: _isPulsingHaptic
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.vibration),
                label: Text(_isPulsingHaptic ? 'Pulsing...' : 'Pulse Haptic'),
              ),
            ],
            
            if (!_isConnected) ...[
              const SizedBox(height: 32),
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


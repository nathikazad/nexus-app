import 'dart:async';
import 'package:flutter/foundation.dart';
import '../ble_service/ble_service.dart';

/// Battery data structure
class BatteryData {
  final int percentage;  // 0-100
  final double voltage;  // Voltage in volts
  final bool isCharging;  // Whether battery is charging

  BatteryData({
    required this.percentage,
    required this.voltage,
    required this.isCharging,
  });
}

class BatteryService {
  final BLEService _bleService;

  BatteryService(this._bleService);
  
  StreamController<BatteryData>? _batteryController;
  Timer? _batteryPollTimer;
  StreamSubscription<bool>? _connectionStateSubscription;
  
  bool _isInitialized = false;

  Stream<BatteryData>? get batteryStream => _batteryController?.stream;
  bool get isInitialized => _isInitialized;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      
      // Initialize battery controller
      _batteryController = StreamController<BatteryData>.broadcast();
      
      // Listen for connection state changes to manage battery polling
      // final connectionStateStream = _bleService.connectionStateStream;
      // if (connectionStateStream != null) {
      //   _connectionStateSubscription = connectionStateStream.listen(
      //     (isConnected) {
      //       if (isConnected) {
      //         _startBatteryPolling();
      //       } else {
      //         _stopBatteryPolling();
      //       }
      //     },
      //     onError: (e) {
      //       debugPrint('BatteryService: Error in connection state stream: $e');
      //     },
      //   );
      // }
      
      // Start battery polling if already connected
      // if (_bleService.isConnected) {
      //   _startBatteryPolling();
      // }
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing BatteryService: $e');
      return false;
    }
  }

  /// Read battery data from device (percentage, voltage, and charging status)
  Future<BatteryData?> readBattery() async {
    final batteryCharacteristic = _bleService.batteryCharacteristic;
    if (!_bleService.isConnected || batteryCharacteristic == null) {
      return null;
    }

    try {
      final data = await batteryCharacteristic.read();
      if (data.length >= 4) {
        // Format: [voltage_msb, voltage_lsb, soc_percent, charging_status]
        final voltageMsb = data[0];
        final voltageLsb = data[1];
        final socPercent = data[2];
        final chargingStatus = data[3];
        
        // Calculate voltage: (msb << 8) | lsb, then divide by 1000 to get volts (raw is in mV)
        final voltageRaw = (voltageMsb << 8) | voltageLsb;
        final voltage = voltageRaw / 1000.0;
        
        // Charging status: 1 = charging, 0 = not charging
        final isCharging = chargingStatus != 0;
        
        final batteryData = BatteryData(
          percentage: socPercent,
          voltage: voltage,
          isCharging: isCharging,
        );
        
        _batteryController?.add(batteryData);
        return batteryData;
      } else if (data.length >= 3) {
        // Backward compatibility: old format without charging status
        final voltageMsb = data[0];
        final voltageLsb = data[1];
        final socPercent = data[2];
        
        final voltageRaw = (voltageMsb << 8) | voltageLsb;
        final voltage = voltageRaw / 1000.0;
        
        final batteryData = BatteryData(
          percentage: socPercent,
          voltage: voltage,
          isCharging: false,  // Default to not charging for old format
        );
        
        _batteryController?.add(batteryData);
        return batteryData;
      }
    } catch (e) {
      debugPrint('Error reading battery: $e');
    }
    return null;
  }
  
  void _startBatteryPolling() {
    _stopBatteryPolling(); // Stop any existing timer
    
    final batteryCharacteristic = _bleService.batteryCharacteristic;
    if (!_bleService.isConnected || batteryCharacteristic == null) {
      return;
    }
    
    // Read battery immediately
    readBattery();
    
    // Poll every 30 seconds for real-time updates
    _batteryPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      readBattery();
    });
  }
  
  void _stopBatteryPolling() {
    _batteryPollTimer?.cancel();
    _batteryPollTimer = null;
  }

  Future<void> dispose() async {
    await _connectionStateSubscription?.cancel();
    _stopBatteryPolling();
    await _batteryController?.close();
    
    _connectionStateSubscription = null;
    _batteryController = null;
    _isInitialized = false;
  }
}


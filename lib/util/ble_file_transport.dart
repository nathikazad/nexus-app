import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Handles file TX/RX/CTRL characteristic communication for BLE
class BLEFileTransport {
  // Characteristic references
  BluetoothCharacteristic? _fileTxCharacteristic;  // NOTIFY (device -> app)
  BluetoothCharacteristic? _fileRxCharacteristic;  // WRITE (app -> device)
  BluetoothCharacteristic? _fileCtrlCharacteristic; // READ/WRITE (control)
  
  StreamSubscription? _txNotificationSubscription;
  
  // Callbacks
  void Function(Uint8List)? onDataReceived;  // Called when FILE_TX_CHAR receives data
  void Function(int, Uint8List)? onControlReceived;  // Called when FILE_CTRL_CHAR receives control
  
  // Dependencies (public for BLEService to set)
  bool Function()? isConnectedCallback;
  int Function()? getMTUCallback;
  
  /// Initialize file transport characteristics from discovered service
  Future<bool> initializeFileTransportCharacteristics(
    BluetoothService service,
    String fileTxUuid,
    String fileRxUuid,
    String fileCtrlUuid,
  ) async {
    _fileTxCharacteristic = null;
    _fileRxCharacteristic = null;
    _fileCtrlCharacteristic = null;
    
    for (BluetoothCharacteristic char in service.characteristics) {
      if (char.uuid.toString().toLowerCase() == fileTxUuid.toLowerCase()) {
        _fileTxCharacteristic = char;
        debugPrint('Found File TX characteristic');
      } else if (char.uuid.toString().toLowerCase() == fileRxUuid.toLowerCase()) {
        _fileRxCharacteristic = char;
        debugPrint('Found File RX characteristic');
      } else if (char.uuid.toString().toLowerCase() == fileCtrlUuid.toLowerCase()) {
        _fileCtrlCharacteristic = char;
        debugPrint('Found File CTRL characteristic');
      }
    }
    
    if (_fileTxCharacteristic == null || 
        _fileRxCharacteristic == null || 
        _fileCtrlCharacteristic == null) {
      debugPrint('Failed to initialize file TX/RX/CTRL characteristics');
      return false;
    }
    
    // Subscribe to FILE_TX_CHAR notifications (incoming file data)
    // Note: For Layer 2, FILE_TX_CHAR may not have CCC descriptor yet, so this is optional
    try {
      await _fileTxCharacteristic!.setNotifyValue(true);
      _txNotificationSubscription = _fileTxCharacteristic!.lastValueStream.listen(
        (data) {
          if (onDataReceived != null) {
            onDataReceived!(Uint8List.fromList(data));
          }
        },
        onError: (error) {
          debugPrint('File TX notification error: $error');
        },
      );
      debugPrint('Subscribed to file TX notifications');
    } catch (e) {
      debugPrint('Warning: Could not subscribe to file TX notifications (may not be needed for Layer 2): $e');
      // Don't fail initialization - FILE_TX notifications aren't needed for Layer 2 control protocol
      // They'll be needed for Layer 3+ when we do actual file data transfer
    }
    
    return true;
  }
  
  /// Send data packet via FILE_RX_CHAR (WRITE)
  Future<void> sendData(Uint8List data) async {
    if (_fileRxCharacteristic == null || !(isConnectedCallback?.call() ?? false)) {
      throw Exception('File RX characteristic not available or not connected');
    }
    await _fileRxCharacteristic!.write(data, withoutResponse: true);
  }
  
  /// Send control command via FILE_CTRL_CHAR (WRITE)
  Future<void> sendControl(int cmd, Uint8List payload) async {
    if (_fileCtrlCharacteristic == null || !(isConnectedCallback?.call() ?? false)) {
      throw Exception('File CTRL characteristic not available or not connected');
    }
    final packet = Uint8List(1 + payload.length);
    packet[0] = cmd;
    packet.setRange(1, packet.length, payload);
    await _fileCtrlCharacteristic!.write(packet, withoutResponse: true);
  }
  
  /// Read control response from FILE_CTRL_CHAR (READ)
  Future<Uint8List?> readControl() async {
    if (_fileCtrlCharacteristic == null || !(isConnectedCallback?.call() ?? false)) {
      return null;
    }
    try {
      final result = await _fileCtrlCharacteristic!.read();
      return Uint8List.fromList(result);
    } catch (e) {
      debugPrint('Error reading control: $e');
      return null;
    }
  }
  
  /// Unsubscribe from notifications
  Future<void> unsubscribeFromNotifications() async {
    try {
      await _fileTxCharacteristic?.setNotifyValue(false);
    } catch (e) {
      debugPrint('Error unsubscribing: $e');
    }
    _txNotificationSubscription?.cancel();
    _txNotificationSubscription = null;
  }
  
  /// Dispose resources
  void dispose() {
    unsubscribeFromNotifications();
  }
}


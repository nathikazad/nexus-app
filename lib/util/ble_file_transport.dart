import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'file_transfer.dart';

/// Handles file TX/RX/CTRL characteristic communication for BLE
class BLEFileTransport {
  // Characteristic references
  BluetoothCharacteristic? _fileTxCharacteristic;  // NOTIFY (device -> app)
  BluetoothCharacteristic? _fileRxCharacteristic;  // WRITE (app -> device)
  BluetoothCharacteristic? _fileCtrlCharacteristic; // READ/WRITE (control)
  
  StreamSubscription? _txNotificationSubscription;
  
  // Callbacks
  void Function(Uint8List)? onDataReceived;  // Called when FILE_TX_CHAR receives data
  void Function(List<FileEntry>)? onListFilesReceived;  // Called when LIST_RESPONSE is received
  void Function(FileEntry)? onFileReceived;  // Reserved for future file receive functionality
  
  // Dependencies (public for BLEService to set)
  bool Function()? isConnectedCallback;
  int Function()? getMTUCallback;

  /// Initialize file transport with callbacks and dependencies
  void initialize({
    void Function(Uint8List)? onDataReceived,
    void Function(List<FileEntry>)? onListFilesReceived,
    void Function(FileEntry)? onFileReceived,
    bool Function()? isConnected,
    int Function()? getMTU,
  }) {
    if (onDataReceived != null) {
      this.onDataReceived = onDataReceived;
    }
    if (onListFilesReceived != null) {
      this.onListFilesReceived = onListFilesReceived;
    }
    if (onFileReceived != null) {
      this.onFileReceived = onFileReceived;
    }
    if (isConnected != null) {
      isConnectedCallback = isConnected;
    }
    if (getMTU != null) {
      getMTUCallback = getMTU;
    }
  }
  
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

  /// Initialize file transport after service discovery
  Future<bool> initializeFileTransport(
    BluetoothService service,
    String fileTxUuid,
    String fileRxUuid,
    String fileCtrlUuid, {
    void Function(Uint8List)? onDataReceived,
    bool Function()? isConnected,
    int Function()? getMTU,
  }) async {
    final success = await initializeFileTransportCharacteristics(
      service,
      fileTxUuid,
      fileRxUuid,
      fileCtrlUuid,
    );

    if (!success) {
      return false;
    }

    initialize(
      isConnected: isConnected,
      getMTU: getMTU,
      onDataReceived: onDataReceived,
    );

    if (onDataReceived != null) {
      this.onDataReceived ??= onDataReceived;
    }

    debugPrint('File transport initialized');
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

  /// Send file request command
  Future<void> sendFileRequest(String path) async {
    final payload = Uint8List.fromList(path.codeUnits + [0]); // null-terminated string
    await sendControl(CMD_START_SEND_FILE, payload);
  }

  /// Send list files request command and handle response
  Future<void> sendListFilesRequest({String? path}) async {
    final payload = path != null
        ? Uint8List.fromList(path.codeUnits + [0])  // null-terminated string
        : Uint8List(0);

    await sendControl(CMD_LIST_FILES, payload);

    // Wait a bit for response to be prepared
    await Future.delayed(const Duration(milliseconds: 100));

    // Read response from FILE_CTRL_CHAR
    final response = await readControl();
    if (response != null && response.isNotEmpty) {
      _handleListResponse(response);
    } else {
      debugPrint('ble file transport: No response received for LIST_FILES');
      onListFilesReceived?.call([]);
    }
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

  void _handleListResponse(Uint8List payload) {
    final fileList = _parseListResponse(payload);
    if (onListFilesReceived != null) {
      debugPrint('ble file transport: Parsed ${fileList.length} files from LIST_RESPONSE');
      onListFilesReceived!(fileList);
    } else {
      debugPrint('ble file transport: No onListFilesReceived callback registered');
    }
  }

  /// Parse LIST_RESPONSE into List<FileEntry>
  List<FileEntry> _parseListResponse(Uint8List payload) {
    // Parse: [0x02][count:2][file1_name_len:1][file1_name][file1_size:4][is_dir:1][...]
    final files = <FileEntry>[];

    if (payload.length < 3) {
      debugPrint('LIST_RESPONSE too short: ${payload.length}');
      return files;
    }

    // Check command byte
    if (payload[0] != CMD_LIST_RESPONSE) {
      debugPrint('Invalid LIST_RESPONSE command: 0x${payload[0].toRadixString(16)}');
      return files;
    }

    // Parse count (2 bytes, big-endian)
    final count = (payload[1] << 8) | payload[2];
    debugPrint('ble file transport: LIST_RESPONSE: $count files');

    int offset = 3;

    for (int i = 0; i < count && offset < payload.length; i++) {
      if (offset + 1 > payload.length) break;
      final nameLen = payload[offset++];

      if (offset + nameLen + 4 + 1 > payload.length) break;

      final name = String.fromCharCodes(payload.sublist(offset, offset + nameLen));
      offset += nameLen;

      final size = (payload[offset] << 24) |
                   (payload[offset + 1] << 16) |
                   (payload[offset + 2] << 8) |
                   payload[offset + 3];
      offset += 4;

      final isDir = payload[offset++] != 0;

      files.add(FileEntry(name: name, size: size, isDirectory: isDir != 0));
    }

    debugPrint('Parsed ${files.length} files from LIST_RESPONSE');
    return files;
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


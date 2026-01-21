import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nexus_voice_assistant/util/file_transfer.dart';
import 'package:nexus_voice_assistant/services/logging_service.dart';

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
  void Function(FileEntry)? onFileReceived;  // Called when file receive completes
  
  // Dependencies (public for BLEService to set)
  bool Function()? isConnectedCallback;
  int Function()? getMTUCallback;
  
  // File receive state
  Map<int, Uint8List>? _receivedPackets;  // seq -> data (null when not receiving)
  String? _receivingFileName;

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
        LoggingService.instance.log('Found File TX characteristic');
      } else if (char.uuid.toString().toLowerCase() == fileRxUuid.toLowerCase()) {
        _fileRxCharacteristic = char;
        LoggingService.instance.log('Found File RX characteristic');
      } else if (char.uuid.toString().toLowerCase() == fileCtrlUuid.toLowerCase()) {
        _fileCtrlCharacteristic = char;
        LoggingService.instance.log('Found File CTRL characteristic');
      }
    }
    
    if (_fileTxCharacteristic == null || 
        _fileRxCharacteristic == null || 
        _fileCtrlCharacteristic == null) {
      LoggingService.instance.log('Failed to initialize file TX/RX/CTRL characteristics');
      return false;
    }
    
    // Subscribe to FILE_TX_CHAR notifications (incoming file data)
    // FILE_TX_CHAR now has a CCC descriptor, so subscription should succeed
    try {
      await _fileTxCharacteristic!.setNotifyValue(true);
      _txNotificationSubscription = _fileTxCharacteristic!.lastValueStream.listen(
        (data) {
          final packet = Uint8List.fromList(data);
          // Handle file data packets if we're receiving a file
          if (_receivedPackets != null) {
            _handleFileDataPacket(packet);
          }
          // Also call the general callback if set
          if (onDataReceived != null) {
            onDataReceived!(packet);
          }
        },
        onError: (error) {
          LoggingService.instance.log('File TX notification error: $error');
        },
      );
      LoggingService.instance.log('Subscribed to file TX notifications');
    } catch (e) {
      LoggingService.instance.log('Error: Could not subscribe to file TX notifications: $e');
      // This should not happen now that CCC descriptor exists, but handle gracefully
      return false;
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

    LoggingService.instance.log('File transport initialized');
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

  /// Send file request command (legacy - use requestFile instead)
  Future<void> sendFileRequest(String path) async {
    final payload = Uint8List.fromList(path.codeUnits + [0]); // null-terminated string
    await sendControl(CMD_START_SEND_FILE, payload);
  }
  
  /// Request a file and handle all receive logic
  /// Collects packets, polls for completion, reassembles file, and calls onFileReceived callback
  Future<void> requestFile(String path) async {
    if (_receivedPackets != null) {
      throw Exception('File receive already in progress');
    }
    
    if (!(isConnectedCallback?.call() ?? false)) {
      throw Exception('Not connected');
    }
    
    LoggingService.instance.log('BLEFileTransport: Starting file receive for: $path');
    
    // Initialize receive state
    _receivedPackets = {};
    _receivingFileName = path.split('/').last;  // Extract filename
    
    // Send START_SEND_FILE command
    final payload = Uint8List.fromList(path.codeUnits + [0]); // null-terminated string
    await sendControl(CMD_START_SEND_FILE, payload);
    
    // Poll for TRANSFER_COMPLETE or TRANSFER_ERROR
    await _pollForTransferComplete();
  }
  
  /// Handle incoming file data packet: [seq:2][data]
  void _handleFileDataPacket(Uint8List packet) {
    if (_receivedPackets == null || packet.length < 2) {
      return;
    }
    
    // Extract sequence number (little-endian, 2 bytes)
    final seq = packet[0] | (packet[1] << 8);
    final packetData = packet.sublist(2);
    
    LoggingService.instance.log('BLEFileTransport: Received packet seq=$seq, data=${packetData.length} bytes');
    
    // Store packet
    _receivedPackets![seq] = packetData;
  }
  
  /// Poll FILE_CTRL_CHAR for TRANSFER_COMPLETE or TRANSFER_ERROR
  Future<void> _pollForTransferComplete() async {
    const maxAttempts = 150;  // 30 seconds / 200ms
    int attempts = 0;
    
    while (attempts < maxAttempts && _receivedPackets != null) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
      
      try {
        final response = await readControl();
        if (response != null && response.isNotEmpty) {
          final cmd = response[0];
          if (cmd == CMD_TRANSFER_COMPLETE) {
            LoggingService.instance.log('BLEFileTransport: Received TRANSFER_COMPLETE');
            await _completeFileReceive();
            return;
          } else if (cmd == CMD_TRANSFER_ERROR) {
            LoggingService.instance.log('BLEFileTransport: Received TRANSFER_ERROR');
            _handleTransferError();
            return;
          }
        }
      } catch (e) {
        LoggingService.instance.log('BLEFileTransport: Error polling control: $e');
      }
    }
    
    // Timeout - check if we have packets
    if (_receivedPackets != null) {
      if (_receivedPackets!.isNotEmpty) {
        LoggingService.instance.log('BLEFileTransport: Polling timeout, but have packets - completing transfer');
        await _completeFileReceive();
      } else {
        LoggingService.instance.log('BLEFileTransport: Transfer timeout - no packets received');
        _handleTransferError();
      }
    }
  }
  
  /// Complete file receive: reassemble and call callback
  Future<void> _completeFileReceive() async {
    if (_receivedPackets == null || _receivedPackets!.isEmpty) {
      LoggingService.instance.log('BLEFileTransport: No packets to reassemble');
      _resetReceiveState();
      return;
    }
    
    // Find max sequence number
    final maxSeq = _receivedPackets!.keys.reduce((a, b) => a > b ? a : b);
    LoggingService.instance.log('BLEFileTransport: Reassembling file: maxSeq=$maxSeq, packets=${_receivedPackets!.length}');
    
    // Reassemble file in order
    final fileData = <int>[];
    for (int seq = 0; seq <= maxSeq; seq++) {
      if (!_receivedPackets!.containsKey(seq)) {
        LoggingService.instance.log('BLEFileTransport: Missing packet $seq');
        _handleTransferError();
        return;
      }
      fileData.addAll(_receivedPackets![seq]!);
    }
    
    LoggingService.instance.log('BLEFileTransport: Reassembled file: ${fileData.length} bytes');
    
    // Write to temporary directory
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${_receivingFileName ?? 'received_file'}');
      await file.writeAsBytes(fileData);
      
      LoggingService.instance.log('BLEFileTransport: File written to ${file.path}');
      
      // Create FileEntry and call callback
      final fileEntry = FileEntry(
        name: _receivingFileName ?? 'received_file',
        size: fileData.length,
        isDirectory: false,
        path: file.path,  // Include file path for displaying images
      );
      
      if (onFileReceived != null) {
        onFileReceived!(fileEntry);
      }
    } catch (e) {
      LoggingService.instance.log('BLEFileTransport: Error writing file: $e');
      _handleTransferError();
      return;
    }
    
    _resetReceiveState();
  }
  
  /// Handle transfer error
  void _handleTransferError() {
    LoggingService.instance.log('BLEFileTransport: Transfer error');
    _resetReceiveState();
    // Could call an error callback here if needed
  }
  
  /// Reset receive state
  void _resetReceiveState() {
    _receivedPackets = null;
    _receivingFileName = null;
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
      LoggingService.instance.log('ble file transport: No response received for LIST_FILES');
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
      LoggingService.instance.log('Error reading control: $e');
      return null;
    }
  }

  void _handleListResponse(Uint8List payload) {
    final fileList = _parseListResponse(payload);
    if (onListFilesReceived != null) {
      LoggingService.instance.log('ble file transport: Parsed ${fileList.length} files from LIST_RESPONSE');
      onListFilesReceived!(fileList);
    } else {
      LoggingService.instance.log('ble file transport: No onListFilesReceived callback registered');
    }
  }

  /// Parse LIST_RESPONSE into List<FileEntry>
  List<FileEntry> _parseListResponse(Uint8List payload) {
    // Parse: [0x02][count:2][file1_name_len:1][file1_name][file1_size:4][is_dir:1][...]
    final files = <FileEntry>[];

    if (payload.length < 3) {
      LoggingService.instance.log('LIST_RESPONSE too short: ${payload.length}');
      return files;
    }

    // Check command byte
    if (payload[0] != CMD_LIST_RESPONSE) {
      LoggingService.instance.log('Invalid LIST_RESPONSE command: 0x${payload[0].toRadixString(16)}');
      return files;
    }

    // Parse count (2 bytes, big-endian)
    final count = (payload[1] << 8) | payload[2];
    LoggingService.instance.log('ble file transport: LIST_RESPONSE: $count files');

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

    LoggingService.instance.log('Parsed ${files.length} files from LIST_RESPONSE');
    return files;
  }
  
  /// Unsubscribe from notifications
  Future<void> unsubscribeFromNotifications() async {
    _txNotificationSubscription?.cancel();
    _txNotificationSubscription = null;
    
    if (_fileTxCharacteristic != null) {
      try {
        // Only try to unsubscribe if device is still connected
        if (_fileTxCharacteristic!.device.isConnected) {
          await _fileTxCharacteristic!.setNotifyValue(false);
        }
      } catch (e) {
        // Ignore errors when device is disconnected - this is expected
        LoggingService.instance.log('Note: Could not unsubscribe file TX (device may be disconnected)');
      }
    }
  }
  
  /// Dispose resources
  void dispose() {
    unsubscribeFromNotifications();
  }
}


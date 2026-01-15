import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/ble_service/ble_file_transport.dart';

class FileEntry {
  final String name;
  final int size;
  final bool isDirectory;
  
  FileEntry({
    required this.name,
    required this.size,
    required this.isDirectory,
  });
  
  @override
  String toString() {
    return '${isDirectory ? "[DIR]" : "[FILE]"} $name ($size bytes)';
  }
}


enum TransferState { idle, sending, receiving, waitingAck }

// Control command codes
const int CMD_LIST_FILES = 0x01;
const int CMD_LIST_RESPONSE = 0x02;
const int CMD_START_SEND_FILE = 0x03;
const int CMD_START_RECEIVE_FILE = 0x04;
const int CMD_PACKET_ACK = 0x05;
const int CMD_TRANSFER_COMPLETE = 0x06;
const int CMD_TRANSFER_ERROR = 0x07;
const int CMD_HASH_MISMATCH = 0x08;

/// File transfer protocol implementation (Layer 2 - Control Protocol)
class FileTransfer {
  final BLEFileTransport transport;
  
  TransferState _state = TransferState.idle;
  
  FileTransfer(this.transport) {
    // Set up callbacks
    transport.onDataReceived = _handleDataPacket;
    // Note: For Layer 2, control responses come via read, not notifications
  }
  
  /// List files on device
  Future<List<FileEntry>> listFiles({String? path}) async {
    if (_state != TransferState.idle) {
      throw Exception('Transfer in progress');
    }
    
    // Send LIST_FILES command
    final payload = path != null 
        ? Uint8List.fromList(path.codeUnits + [0])  // null-terminated string
        : Uint8List(0);
    
    await transport.sendControl(CMD_LIST_FILES, payload);
    
    // Wait a bit for response to be prepared
    await Future.delayed(Duration(milliseconds: 100));
    
    // Read response from FILE_CTRL_CHAR
    final response = await transport.readControl();
    if (response == null || response.isEmpty) {
      debugPrint('file transfer: No response received for LIST_FILES');
      return [];
    }
    
    // Parse response
    return _parseListResponse(response);
  }
  
  /// Handle received data packet (Layer 2: just log)
  void _handleDataPacket(Uint8List data) {
    debugPrint('FileTransfer: Received data packet, length ${data.length}');
    // Layer 2: Just log data packets, will be implemented in later layers
  }
  
  /// Parse LIST_RESPONSE
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
    debugPrint('file transfer: LIST_RESPONSE: $count files');
    
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
  
  void dispose() {
    transport.dispose();
  }
}


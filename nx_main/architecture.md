# Mobile App File Transfer Architecture

## Overview

This document describes the mobile app architecture for file transfer over BLE, mirroring the firmware's layered design. The architecture separates transport concerns from protocol logic, making it easy to test and maintain.

## Architecture Layers

```
┌─────────────────────────────────────┐
│   FileTransfer (Protocol Layer)    │  ← Handles packets, ACKs, retries, hashes
│   - Packet sequencing              │
│   - ACK tracking                   │
│   - Retry logic                    │
│   - Hash verification              │
│   - File I/O                       │
└──────────────┬────────────────────┘
               │ uses
               ▼
┌─────────────────────────────────────┐
│   BLEFileTransport                  │  ← BLE-specific implementation
│   - Characteristic management      │
│   - Notification subscriptions     │
│   - Packet sending                 │
└──────────────┬────────────────────┘
               │ uses
               ▼
┌─────────────────────────────────────┐
│   BLEService                       │  ← BLE connection & discovery
│   - Device connection              │
│   - Service discovery              │
│   - Characteristic discovery       │
└─────────────────────────────────────┘
```

## Component Design

### 1. BLEFileTransport

**File:** `lib/util/ble_file_transport.dart`

Similar to `BLEAudioTransport`, handles file-specific BLE communication:

```dart
/// Handles file TX/RX/CTRL characteristic communication for BLE
class BLEFileTransport {
  // Characteristic references
  BluetoothCharacteristic? _fileTxCharacteristic;  // NOTIFY (device -> app)
  BluetoothCharacteristic? _fileRxCharacteristic;  // WRITE (app -> device)
  BluetoothCharacteristic? _fileCtrlCharacteristic; // READ/WRITE (control)
  
  StreamSubscription? _txNotificationSubscription;
  StreamSubscription? _ctrlNotificationSubscription;
  
  // Callbacks
  void Function(Uint8List)? onDataReceived;  // Called when FILE_TX_CHAR receives data
  void Function(int, Uint8List)? onControlReceived;  // Called when FILE_CTRL_CHAR receives control
  
  // Dependencies
  bool Function()? _isConnected;
  int Function()? _getMTU;
  
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
      debugPrint('Error subscribing to file TX notifications: $e');
      return false;
    }
    
    // Subscribe to FILE_CTRL_CHAR notifications (control responses)
    try {
      await _fileCtrlCharacteristic!.setNotifyValue(true);
      _ctrlNotificationSubscription = _fileCtrlCharacteristic!.lastValueStream.listen(
        (data) {
          if (data.isNotEmpty && onControlReceived != null) {
            final cmd = data[0];
            final payload = data.length > 1 ? Uint8List.fromList(data.sublist(1)) : Uint8List(0);
            onControlReceived!(cmd, payload);
          }
        },
        onError: (error) {
          debugPrint('File CTRL notification error: $error');
        },
      );
      debugPrint('Subscribed to file CTRL notifications');
    } catch (e) {
      debugPrint('Error subscribing to file CTRL notifications: $e');
      return false;
    }
    
    return true;
  }
  
  /// Send data packet via FILE_RX_CHAR (WRITE)
  Future<void> sendData(Uint8List data) async {
    if (_fileRxCharacteristic == null || !(_isConnected?.call() ?? false)) {
      throw Exception('File RX characteristic not available or not connected');
    }
    await _fileRxCharacteristic!.write(data, withoutResponse: true);
  }
  
  /// Send control command via FILE_CTRL_CHAR (WRITE)
  Future<void> sendControl(int cmd, Uint8List payload) async {
    if (_fileCtrlCharacteristic == null || !(_isConnected?.call() ?? false)) {
      throw Exception('File CTRL characteristic not available or not connected');
    }
    final packet = Uint8List(1 + payload.length);
    packet[0] = cmd;
    packet.setRange(1, packet.length, payload);
    await _fileCtrlCharacteristic!.write(packet, withoutResponse: true);
  }
  
  /// Read control response from FILE_CTRL_CHAR (READ)
  Future<Uint8List?> readControl() async {
    if (_fileCtrlCharacteristic == null || !(_isConnected?.call() ?? false)) {
      return null;
    }
    try {
      return await _fileCtrlCharacteristic!.read();
    } catch (e) {
      debugPrint('Error reading control: $e');
      return null;
    }
  }
  
  /// Unsubscribe from notifications
  Future<void> unsubscribeFromNotifications() async {
    try {
      await _fileTxCharacteristic?.setNotifyValue(false);
      await _fileCtrlCharacteristic?.setNotifyValue(false);
    } catch (e) {
      debugPrint('Error unsubscribing: $e');
    }
    _txNotificationSubscription?.cancel();
    _ctrlNotificationSubscription?.cancel();
    _txNotificationSubscription = null;
    _ctrlNotificationSubscription = null;
  }
  
  /// Dispose resources
  void dispose() {
    unsubscribeFromNotifications();
  }
}
```

**Key Features:**
- Manages FILE_TX, FILE_RX, FILE_CTRL characteristics
- Handles notification subscriptions
- Provides simple send/receive interface
- Similar pattern to `BLEAudioTransport`

### 2. FileTransfer Protocol Layer

**File:** `lib/util/file_transfer.dart`

Transport-agnostic protocol implementation:

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'ble_file_transport.dart';
import '../models/file_entry.dart';

enum TransferState { idle, sending, receiving, waitingAck }

/// File transfer protocol implementation
class FileTransfer {
  final BLEFileTransport transport;
  
  TransferState _state = TransferState.idle;
  
  // Transfer state
  String? _currentFilename;
  int? _fileSize;
  int? _hash;
  int? _totalPackets;
  Map<int, Uint8List> _receivedPackets = {};  // seq_num -> packet data
  Set<int> _ackedPackets = {};  // Track ACKed packets
  Set<int> _missingPackets = {};  // Track missing packets
  Map<int, Uint8List> _packetsToSend = {};  // seq_num -> packet data (for sending)
  
  Timer? _retryTimer;
  Completer<List<FileEntry>>? _listFilesCompleter;
  Completer<bool>? _receiveFileCompleter;
  Completer<bool>? _sendFileCompleter;
  
  FileTransfer(this.transport) {
    // Set up callbacks
    transport.onDataReceived = _handleDataPacket;
    transport.onControlReceived = _handleControlCommand;
  }
  
  /// List files on device
  Future<List<FileEntry>> listFiles({String? path}) async {
    if (_state != TransferState.idle) {
      throw Exception('Transfer in progress');
    }
    
    _listFilesCompleter = Completer<List<FileEntry>>();
    
    // Send LIST_FILES command
    final payload = path != null 
        ? Uint8List.fromList(path.codeUnits + [0])  // null-terminated string
        : Uint8List(0);
    
    await transport.sendControl(0x01, payload);  // LIST_FILES
    
    // Wait for response (handled in _handleControlCommand)
    return await _listFilesCompleter!.future;
  }
  
  /// Send file from device to app
  Future<bool> receiveFile(String filename, String savePath) async {
    if (_state != TransferState.idle) {
      throw Exception('Transfer in progress');
    }
    
    _state = TransferState.receiving;
    _receiveFileCompleter = Completer<bool>();
    _currentFilename = filename;
    _receivedPackets.clear();
    _ackedPackets.clear();
    _missingPackets.clear();
    
    // Send START_SEND_FILE command
    final payload = Uint8List.fromList(filename.codeUnits + [0]);
    await transport.sendControl(0x03, payload);  // START_SEND_FILE
    
    // Wait for response with file metadata (handled in _handleControlCommand)
    // Then wait for packets (handled in _handleDataPacket)
    return await _receiveFileCompleter!.future;
  }
  
  /// Send file from app to device
  Future<bool> sendFile(String localPath, String remoteFilename) async {
    if (_state != TransferState.idle) {
      throw Exception('Transfer in progress');
    }
    
    _state = TransferState.sending;
    _sendFileCompleter = Completer<bool>();
    _currentFilename = remoteFilename;
    _packetsToSend.clear();
    _ackedPackets.clear();
    _missingPackets.clear();
    
    // Read local file
    final file = File(localPath);
    if (!await file.exists()) {
      _state = TransferState.idle;
      return false;
    }
    
    final fileData = await file.readAsBytes();
    _fileSize = fileData.length;
    _hash = _computeHash(fileData);
    
    // Calculate packet count
    final mtu = transport._getMTU?.call() ?? 20;
    final payloadSize = mtu - 5;  // MTU - 3 (ATT) - 2 (seq_num)
    _totalPackets = (_fileSize! / payloadSize).ceil();
    
    // Split file into packets
    for (int i = 0; i < _totalPackets!; i++) {
      final offset = i * payloadSize;
      final length = (offset + payloadSize > _fileSize!) 
          ? _fileSize! - offset 
          : payloadSize;
      final packetData = fileData.sublist(offset, offset + length);
      
      // Create packet: [seq:2][data...]
      final packet = Uint8List(2 + length);
      packet[0] = (i >> 8) & 0xFF;
      packet[1] = i & 0xFF;
      packet.setRange(2, packet.length, packetData);
      
      _packetsToSend[i] = packet;
    }
    
    // Send START_RECEIVE_FILE command
    final payload = Uint8List(1 + remoteFilename.length + 4 + 4);
    payload[0] = remoteFilename.length;
    payload.setRange(1, 1 + remoteFilename.length, remoteFilename.codeUnits);
    payload[1 + remoteFilename.length] = (_fileSize! >> 24) & 0xFF;
    payload[2 + remoteFilename.length] = (_fileSize! >> 16) & 0xFF;
    payload[3 + remoteFilename.length] = (_fileSize! >> 8) & 0xFF;
    payload[4 + remoteFilename.length] = _fileSize! & 0xFF;
    payload[5 + remoteFilename.length] = (_hash! >> 24) & 0xFF;
    payload[6 + remoteFilename.length] = (_hash! >> 16) & 0xFF;
    payload[7 + remoteFilename.length] = (_hash! >> 8) & 0xFF;
    payload[8 + remoteFilename.length] = _hash! & 0xFF;
    
    await transport.sendControl(0x04, payload);  // START_RECEIVE_FILE
    
    // Start sending packets
    _startSendingPackets();
    
    // Wait for completion
    return await _sendFileCompleter!.future;
  }
  
  void _handleDataPacket(Uint8List data) {
    if (data.length < 2) return;
    
    // Parse packet: [seq:2][data...]
    final seqNum = (data[0] << 8) | data[1];
    final packetData = data.sublist(2);
    
    // Store packet
    _receivedPackets[seqNum] = packetData;
    
    // Send ACK
    final ackPayload = Uint8List(2);
    ackPayload[0] = (seqNum >> 8) & 0xFF;
    ackPayload[1] = seqNum & 0xFF;
    transport.sendControl(0x05, ackPayload);  // PACKET_ACK
    
    // Check if all packets received
    if (_receivedPackets.length == _totalPackets) {
      _reassembleFile();
    }
  }
  
  void _handleControlCommand(int cmd, Uint8List payload) {
    switch (cmd) {
      case 0x02: // LIST_RESPONSE
        _parseListResponse(payload);
        break;
      case 0x03: // START_SEND_FILE response
        _parseSendFileResponse(payload);
        break;
      case 0x05: // PACKET_ACK
        _handlePacketAck(payload);
        break;
      case 0x06: // TRANSFER_COMPLETE
        _handleTransferComplete();
        break;
      case 0x07: // TRANSFER_ERROR
        _handleTransferError(payload);
        break;
      case 0x08: // HASH_MISMATCH
        _handleHashMismatch();
        break;
    }
  }
  
  void _parseListResponse(Uint8List payload) {
    // Parse: [count:2][file1_name_len:1][file1_name][file1_size:4][is_dir:1][...]
    final files = <FileEntry>[];
    int offset = 0;
    
    if (payload.length < 2) return;
    
    final count = (payload[0] << 8) | payload[1];
    offset = 2;
    
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
      
      files.add(FileEntry(name: name, size: size, isDirectory: isDir));
    }
    
    if (_listFilesCompleter != null && !_listFilesCompleter!.isCompleted) {
      _listFilesCompleter!.complete(files);
      _listFilesCompleter = null;
    }
  }
  
  void _parseSendFileResponse(Uint8List payload) {
    // Parse: [filename_len:1][filename][file_size:4][hash:4][total_packets:4]
    if (payload.length < 10) return;
    
    final nameLen = payload[0];
    if (payload.length < 1 + nameLen + 4 + 4 + 4) return;
    
    _currentFilename = String.fromCharCodes(payload.sublist(1, 1 + nameLen));
    _fileSize = (payload[1 + nameLen] << 24) |
                (payload[2 + nameLen] << 16) |
                (payload[3 + nameLen] << 8) |
                payload[4 + nameLen];
    _hash = (payload[5 + nameLen] << 24) |
            (payload[6 + nameLen] << 16) |
            (payload[7 + nameLen] << 8) |
            payload[8 + nameLen];
    _totalPackets = (payload[9 + nameLen] << 24) |
                    (payload[10 + nameLen] << 16) |
                    (payload[11 + nameLen] << 8) |
                    payload[12 + nameLen];
    
    debugPrint('File: $_currentFilename, Size: $_fileSize, Packets: $_totalPackets');
  }
  
  void _handlePacketAck(Uint8List payload) {
    if (payload.length < 2) return;
    
    final seqNum = (payload[0] << 8) | payload[1];
    _ackedPackets.add(seqNum);
    
    // Check if all packets ACKed
    if (_state == TransferState.sending && 
        _ackedPackets.length == _totalPackets) {
      // Send TRANSFER_COMPLETE
      transport.sendControl(0x06, Uint8List.fromList([1]));  // direction: app->device
      _state = TransferState.idle;
      if (_sendFileCompleter != null && !_sendFileCompleter!.isCompleted) {
        _sendFileCompleter!.complete(true);
        _sendFileCompleter = null;
      }
    }
  }
  
  void _reassembleFile() {
    // Reassemble file from packets
    final fileData = <int>[];
    for (int i = 0; i < _totalPackets!; i++) {
      if (!_receivedPackets.containsKey(i)) {
        debugPrint('Missing packet: $i');
        return;  // Wait for missing packet
      }
      fileData.addAll(_receivedPackets[i]!);
    }
    
    final data = Uint8List.fromList(fileData);
    
    // Verify hash
    final computedHash = _computeHash(data);
    if (computedHash != _hash) {
      debugPrint('Hash mismatch! Expected: $_hash, Got: $computedHash');
      transport.sendControl(0x08, Uint8List.fromList([0]));  // HASH_MISMATCH, direction: device->app
      _state = TransferState.idle;
      if (_receiveFileCompleter != null && !_receiveFileCompleter!.isCompleted) {
        _receiveFileCompleter!.complete(false);
        _receiveFileCompleter = null;
      }
      return;
    }
    
    // Save file (savePath should be provided, using _currentFilename for now)
    // TODO: Use savePath parameter
    _state = TransferState.idle;
    if (_receiveFileCompleter != null && !_receiveFileCompleter!.isCompleted) {
      _receiveFileCompleter!.complete(true);
      _receiveFileCompleter = null;
    }
  }
  
  void _startSendingPackets() {
    // Send all packets
    for (final entry in _packetsToSend.entries) {
      transport.sendData(entry.value);
    }
    
    // Start retry timer
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(Duration(milliseconds: 500), (_) {
      _retryMissingPackets();
    });
  }
  
  void _retryMissingPackets() {
    if (_state != TransferState.sending) return;
    
    // Find missing packets
    for (int i = 0; i < _totalPackets!; i++) {
      if (!_ackedPackets.contains(i) && _packetsToSend.containsKey(i)) {
        // Resend packet
        transport.sendData(_packetsToSend[i]!);
      }
    }
  }
  
  void _handleTransferComplete() {
    _retryTimer?.cancel();
    _state = TransferState.idle;
    // Already handled in _handlePacketAck for sending
  }
  
  void _handleTransferError(Uint8List payload) {
    _retryTimer?.cancel();
    _state = TransferState.idle;
    if (_sendFileCompleter != null && !_sendFileCompleter!.isCompleted) {
      _sendFileCompleter!.complete(false);
      _sendFileCompleter = null;
    }
    if (_receiveFileCompleter != null && !_receiveFileCompleter!.isCompleted) {
      _receiveFileCompleter!.complete(false);
      _receiveFileCompleter = null;
    }
  }
  
  void _handleHashMismatch() {
    _retryTimer?.cancel();
    _state = TransferState.idle;
    if (_sendFileCompleter != null && !_sendFileCompleter!.isCompleted) {
      _sendFileCompleter!.complete(false);
      _sendFileCompleter = null;
    }
  }
  
  int _computeHash(Uint8List data) {
    final bytes = sha256.convert(data).bytes;
    // Use first 4 bytes as CRC32-like hash
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }
  
  void dispose() {
    _retryTimer?.cancel();
    transport.dispose();
  }
}
```

### 3. File Entry Model

**File:** `lib/models/file_entry.dart`

```dart
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
```

### 4. BLEService Integration

**Modifications to:** `lib/services/ble_service.dart`

Add file transfer support similar to audio:

```dart
class BLEService {
  // ... existing code ...
  
  // File transfer UUIDs
  static const String fileTxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ae";
  static const String fileRxCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26af";
  static const String fileCtrlCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26b0";
  
  // File transport
  final BLEFileTransport _fileTransport = BLEFileTransport();
  FileTransfer? _fileTransfer;
  
  FileTransfer? get fileTransfer => _fileTransfer;
  
  /// Initialize file transport (called after service discovery)
  Future<bool> _initializeFileTransport(BluetoothService service) async {
    final success = await _fileTransport.initializeFileTransportCharacteristics(
      service,
      fileTxCharacteristicUuid,
      fileRxCharacteristicUuid,
      fileCtrlCharacteristicUuid,
    );
    
    if (success) {
      // Set dependencies
      _fileTransport._isConnected = () => isConnected;
      _fileTransport._getMTU = () => getMTU();
      
      // Create FileTransfer instance
      _fileTransfer = FileTransfer(_fileTransport);
      debugPrint('File transfer initialized');
      return true;
    }
    return false;
  }
  
  // In _connectToDevice(), after line 344 (after audio transport init):
  // Add:
  if (!await _initializeFileTransport(targetService)) {
    debugPrint('Failed to initialize file transport');
  }
  
  // In _reinitializeAfterRestore(), after line 459:
  // Add:
  await _initializeFileTransport(targetService);
  
  // In disconnect(), add:
  await _fileTransport.unsubscribeFromNotifications();
  _fileTransfer = null;
}
```

## Usage Example (Testing)

```dart
// In a test widget or button handler

final bleService = BLEService();
await bleService.initialize();

// Wait for connection...

final fileTransfer = bleService.fileTransfer;
if (fileTransfer == null) {
  print('File transfer not initialized');
  return;
}

// List files
final files = await fileTransfer.listFiles();
for (final file in files) {
  print('${file.isDirectory ? "[DIR]" : "[FILE]"} ${file.name} (${file.size} bytes)');
}

// Receive file from device
final success = await fileTransfer.receiveFile(
  'radio.wav',
  '/tmp/radio.wav',  // Use path_provider for real app
);
print('Receive ${success ? "succeeded" : "failed"}');

// Send file to device
final success2 = await fileTransfer.sendFile(
  '/tmp/test.jpg',
  'image.jpg',
);
print('Send ${success2 ? "succeeded" : "failed"}');
```

## Simple Button-Based Testing

```dart
// In main.dart or test widget

ElevatedButton(
  onPressed: () async {
    final files = await bleService.fileTransfer?.listFiles();
    files?.forEach((f) => print('${f.isDirectory ? "[DIR]" : "[FILE]"} ${f.name}: ${f.size}'));
  },
  child: Text('List Files'),
),

ElevatedButton(
  onPressed: () async {
    final success = await bleService.fileTransfer?.receiveFile(
      'radio.wav',
      '/tmp/radio.wav',  // Use path_provider for real app
    );
    print('Receive ${success ? "succeeded" : "failed"}');
  },
  child: Text('Receive File'),
),

ElevatedButton(
  onPressed: () async {
    final success = await bleService.fileTransfer?.sendFile(
      '/tmp/test.jpg',
      'test.jpg',
    );
    print('Send ${success ? "succeeded" : "failed"}');
  },
  child: Text('Send File'),
),
```

## File Structure

```
lib/
├── services/
│   └── ble_service.dart          (modified - add file transport)
├── util/
│   ├── ble_file_transport.dart   (NEW - BLE file transport)
│   ├── file_transfer.dart        (NEW - protocol layer)
│   ├── ble_audio_transport.dart  (existing)
│   └── ble_queue.dart            (existing)
├── models/
│   └── file_entry.dart           (NEW - file list model)
└── main.dart                     (test buttons)
```

## Implementation Details

### Packet Format

**Data Packets (FILE_TX_CHAR / FILE_RX_CHAR):**
```dart
[sequence:2 bytes, big-endian][data:MTU-5 bytes]
```

**Control Packets (FILE_CTRL_CHAR):**
```dart
[command:1 byte][payload_length:1 byte][payload:variable]
```

### ACK Mechanism

1. **Receiving packets:**
   - Parse sequence number from packet
   - Store packet in `_receivedPackets` map
   - Send `PACKET_ACK` command with sequence number
   - Track received packets to detect gaps

2. **Sending packets:**
   - Send packet with sequence number
   - Wait for ACK (with timeout)
   - Retry if ACK not received
   - Track ACKed packets

### Retry Logic

```dart
void _startRetryTimer() {
  _retryTimer?.cancel();
  _retryTimer = Timer.periodic(Duration(milliseconds: 500), (_) {
    _retryMissingPackets();
  });
}

void _retryMissingPackets() {
  if (_state != TransferState.sending) return;
  
  for (int i = 0; i < _totalPackets!; i++) {
    if (!_ackedPackets.contains(i) && _packetsToSend.containsKey(i)) {
      // Resend packet
      transport.sendData(_packetsToSend[i]!);
    }
  }
}
```

### Hash Verification

```dart
import 'package:crypto/crypto.dart';

int _computeHash(Uint8List data) {
  final bytes = sha256.convert(data).bytes;
  // Use first 4 bytes as CRC32-like hash (or full 32 bytes)
  return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
}
```

## Benefits

1. **Consistent Pattern**: Mirrors `BLEAudioTransport` pattern
2. **Separation of Concerns**: Transport separate from protocol
3. **Testable**: Can mock `BLEFileTransport` for unit tests
4. **Maintainable**: Changes to BLE don't affect protocol logic
5. **Reusable**: `FileTransfer` could work with other transports

## Integration Checklist

- [ ] Add file characteristic UUIDs to `BLEService`
- [ ] Create `BLEFileTransport` class
- [ ] Create `FileTransfer` protocol class
- [ ] Create `FileEntry` model
- [ ] Integrate file transport initialization in `BLEService._connectToDevice()`
- [ ] Integrate file transport initialization in `BLEService._reinitializeAfterRestore()`
- [ ] Add cleanup in `BLEService.disconnect()`
- [ ] Add test buttons for list/send/receive
- [ ] Implement packet sequencing and ACK tracking
- [ ] Implement retry logic
- [ ] Implement hash verification
- [ ] Test with small files first
- [ ] Test with packet loss simulation

## Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  crypto: ^3.0.0  # For hash computation
  path_provider: ^2.0.0  # For file paths (optional, for real app)
```


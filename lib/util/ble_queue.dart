import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Manages packet queue, batching, and sending for BLE communication
class PacketQueue {
  // Signal constants
  static const int signalEof = 0xFFFC;
  
  final Queue<Uint8List> _packetQueue = Queue<Uint8List>();
  Uint8List _currentBatch = Uint8List(0);
  bool _senderRunning = false;
  Timer? _senderTimer;
  bool _isProcessing = false;
  
  // Dependencies provided via callbacks
  final bool Function() _isConnected;
  final int Function() _getMTU;
  final BluetoothCharacteristic? Function() _getRxCharacteristic;
  final bool Function() _isPaused;
  
  PacketQueue({
    required bool Function() isConnected,
    required int Function() getMTU,
    required BluetoothCharacteristic? Function() getRxCharacteristic,
    required bool Function() isPaused,
  })  : _isConnected = isConnected,
        _getMTU = getMTU,
        _getRxCharacteristic = getRxCharacteristic,
        _isPaused = isPaused;
  
  /// Enqueue a packet to be sent. Packets are batched up to MTU size before being queued.
  void enqueuePacket(Uint8List packet) {
    if (packet.isEmpty) {
      return;
    }

    final mtu = _getMTU();

    // If adding this packet would exceed MTU and we have a batch, enqueue current batch
    if (_currentBatch.isNotEmpty && _currentBatch.length + packet.length > mtu) {
      _packetQueue.add(_currentBatch);
      // debugPrint('[BATCH] Enqueued batch: ${_currentBatch.length} bytes (queue size: ${_packetQueue.length})');
      _currentBatch = Uint8List(0);
    }

    // Add packet to current batch
    if (_currentBatch.isEmpty) {
      _currentBatch = Uint8List.fromList(packet);
    } else {
      final newBatch = Uint8List(_currentBatch.length + packet.length);
      newBatch.setRange(0, _currentBatch.length, _currentBatch);
      newBatch.setRange(_currentBatch.length, _currentBatch.length + packet.length, packet);
      _currentBatch = newBatch;
    }
  }

  /// Enqueue an EOF packet. It will be sent after all queued audio packets.
  /// Flushes any pending batch first.
  void enqueueEOF() {
    // Flush any pending batch
    if (_currentBatch.isNotEmpty) {
      _packetQueue.add(_currentBatch);
      debugPrint('[BATCH] Enqueued final batch: ${_currentBatch.length} bytes (queue size: ${_packetQueue.length})');
      _currentBatch = Uint8List(0);
    }

    // Create and enqueue EOF packet
    Uint8List eofPacket = Uint8List(2);
    eofPacket[0] = signalEof & 0xFF;
    eofPacket[1] = (signalEof >> 8) & 0xFF;
    _packetQueue.add(eofPacket);
    debugPrint('[QUEUE] Enqueued EOF packet (queue size: ${_packetQueue.length})');
  }

  /// Check if a packet is an EOF packet
  bool _isEOFPacket(Uint8List packet) {
    if (packet.length != 2) {
      return false;
    }
    final identifier = packet[0] | (packet[1] << 8);
    return identifier == signalEof;
  }

  /// Start the background packet sender that processes the queue
  void start() {
    if (_senderRunning) {
      return;
    }
    _senderRunning = true;
    _senderTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _processQueue();
    });
    debugPrint('[SENDER] Started background packet sender');
  }

  /// Stop the background packet sender
  void stop() {
    _senderRunning = false;
    _senderTimer?.cancel();
    _senderTimer = null;
    debugPrint('[SENDER] Stopped background packet sender');
  }

  /// Process the packet queue - sends ready-to-send batches
  Future<void> _processQueue() async {
    if (!_isConnected() || _getRxCharacteristic() == null || _isPaused() || _packetQueue.isEmpty || _isProcessing) {
      return;
    }
    _isProcessing = true;
    print('Processing queue');
    try {
      int packetsSent = 0;
      // Process one batch at a time (batches are already constructed)
      while (_packetQueue.isNotEmpty && !_isPaused()) {
        final batch = _packetQueue.first;
        
        // Check if this is an EOF packet
        if (_isEOFPacket(batch)) {
          // Send EOF packet immediately (not batched)
          _packetQueue.removeFirst();
          await _sendPacket(batch);
          debugPrint('[SEND] Sent EOF packet');
          break; // EOF is always the last packet
        }


        
        // Send the batch (already batched up to MTU)
        _packetQueue.removeFirst();
        await _sendBatch(batch);
        await Future.delayed(const Duration(milliseconds: 100));
        if (++packetsSent >= 5) {
          print('Exiting after 5 packets');
          break;
        }
      }
    } catch (e) {
      debugPrint('[SENDER] Error processing queue: $e');
    }
    finally {
      _isProcessing = false;
    }
  }

  /// Internal method to send a batch to the BLE characteristic
  Future<void> _sendBatch(Uint8List batch) async {
    final rxCharacteristic = _getRxCharacteristic();
    if (rxCharacteristic == null || !_isConnected() || batch.isEmpty) {
      return;
    }

    try {
      final now = DateTime.now();
      final seconds = now.millisecondsSinceEpoch ~/ 1000;
      final milliseconds = now.millisecondsSinceEpoch % 1000;
      debugPrint('[SEND] Sending batch: ${batch.length} bytes [${seconds}.${milliseconds.toString().padLeft(3, '0')}]');
      await rxCharacteristic.write(batch, withoutResponse: true);
    } catch (e) {
      debugPrint('[SEND] Error sending batch: $e');
      rethrow;
    }
  }

  /// Internal method to send a single packet (for EOF signals)
  Future<void> _sendPacket(Uint8List packet) async {
    final rxCharacteristic = _getRxCharacteristic();
    if (rxCharacteristic == null || !_isConnected()) {
      debugPrint('[SEND] Cannot send packet: not connected or RX characteristic not available');
      return;
    }

    try {
      debugPrint('[SEND] Sending packet: ${packet.length} bytes');
      await rxCharacteristic.write(packet, withoutResponse: true);
    } catch (e) {
      debugPrint('[SEND] Error sending packet: $e');
      rethrow;
    }
  }
  
  /// Clear the queue and current batch
  void clear() {
    _packetQueue.clear();
    _currentBatch = Uint8List(0);
  }
  
  /// Dispose resources
  void dispose() {
    stop();
    clear();
  }
}


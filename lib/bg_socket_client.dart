import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Interface for listening to Opus batch sending events
abstract class IOpusBatchListener {
  /// Called when a batch should be sent
  Future<void> sendBatch(Uint8List batch);
  
  /// Called when EOF signal should be sent
  Future<void> sendEof();
}

class _QueuedPacket {
  final Uint8List data;
  final int? index;

  _QueuedPacket(this.data, this.index);
}

class SocketClient {
  WebSocketChannel? _channel;
  String? _url;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);
  
  // Packet queue for when socket is disconnected
  final List<_QueuedPacket> _packetQueue = [];
  static const int maxQueueSize = 1000; // Limit queue size to prevent memory issues
  
  // BLE helper for sending Opus batches
  IOpusBatchListener? _opusListener;
  int _effectiveMtu = 20; // Default MTU

  bool get isConnected => _isConnected;
  int get queuedPacketCount => _packetQueue.length;
  
  /// Set BLE helper and MTU for Opus playback
  void setMtu(IOpusBatchListener listener, int effectiveMtu) {
    _opusListener = listener;
    _effectiveMtu = effectiveMtu;
  }

  Future<bool> connect(String url) async {
    if (_isConnected && _url == url) {
      debugPrint("[Socket] Already connected to $url");
      return true;
    }

    _url = url;
    return await _connect();
  }

  Future<bool> _connect() async {
    if (_url == null) {
      debugPrint("[Socket] No URL provided");
      return false;
    }

    try {
      debugPrint("[Socket] Connecting to $_url...");
      
      _channel = IOWebSocketChannel.connect(
        _url!,
        pingInterval: const Duration(seconds: 20),
        connectTimeout: const Duration(seconds: 10),
      );

      await _channel!.ready;
      _isConnected = true;
      _reconnectAttempts = 0;
      
      debugPrint("[Socket] Connected to $_url");
      
      // Send queued packets if any
      _flushPacketQueue();

      // Listen for messages from server
      _channel!.stream.listen(
        (message) {
          debugPrint("[Socket] Received: $message");
        },
        onError: (error) {
          debugPrint("[Socket] Error: $error");
          _handleDisconnection();
        },
        onDone: () {
          debugPrint("[Socket] Connection closed");
          _handleDisconnection();
        },
        cancelOnError: true,
      );

      return true;
    } catch (e) {
      debugPrint("[Socket] Connection failed: $e");
      _isConnected = false;
      _scheduleReconnect();
      return false;
    }
  }

  void sendPacket(Uint8List data, {int? index}) {
    // Check for EOF signal (0xFFFC) - 2 bytes little-endian
    if (data.length >= 2) {
      final identifier = data[0] | (data[1] << 8);
      const int signalEof = 0xFFFC;
      
      if (identifier == signalEof) {
        debugPrint("[Socket] EOF signal detected, triggering Opus playback");
        // Trigger Opus playback asynchronously
        if (_opusListener != null) {
          sendOpusFileInBatches().catchError((e) {
            debugPrint("[Socket] Error triggering Opus playback: $e");
          });
        } else {
          debugPrint("[Socket] Opus listener not set, cannot trigger playback");
        }
        // Still forward EOF to socket server
      }
    }
    
    // If not connected, queue the packet
    if (!_isConnected || _channel == null) {
      _queuePacket(data, index);
      return;
    }

    try {
      _sendPacketData(data, index);
    } catch (e) {
      debugPrint("[Socket] Send error: $e");
      // Queue the packet if send fails
      _queuePacket(data, index);
      _handleDisconnection();
    }
  }
  
  void _sendPacketData(Uint8List data, int? index) {
    if (index != null) {
      // Format: [4 bytes index (uint32 little-endian)] + [payload data]
      final indexBytes = Uint8List(4);
      final byteData = ByteData.view(indexBytes.buffer);
      byteData.setUint32(0, index, Endian.little);
      
      // Combine index + payload
      final combined = Uint8List(4 + data.length);
      combined.setRange(0, 4, indexBytes);
      combined.setRange(4, 4 + data.length, data);
      
      _channel!.sink.add(combined);
    } else {
      // Send as binary data without index
      _channel!.sink.add(data);
    }
  }
  
  void _queuePacket(Uint8List data, int? index) {
    // Limit queue size to prevent memory issues
    if (_packetQueue.length >= maxQueueSize) {
      debugPrint("[Socket] Queue full (${_packetQueue.length} packets), dropping oldest packet");
      _packetQueue.removeAt(0);
    }
    
    // Create a copy of the data to avoid issues if the original is modified
    final dataCopy = Uint8List.fromList(data);
    _packetQueue.add(_QueuedPacket(dataCopy, index));
    
    if (_packetQueue.length == 1) {
      debugPrint("[Socket] Queueing packet (queue size: 1)");
    } else if (_packetQueue.length % 100 == 0) {
      debugPrint("[Socket] Queue size: ${_packetQueue.length} packets");
    }
  }
  
  void _flushPacketQueue() {
    if (_packetQueue.isEmpty) {
      return;
    }
    
    final queueSize = _packetQueue.length;
    debugPrint("[Socket] Flushing $queueSize queued packets...");
    
    try {
      for (final packet in _packetQueue) {
        _sendPacketData(packet.data, packet.index);
      }
      
      debugPrint("[Socket] Successfully sent $queueSize queued packets");
      _packetQueue.clear();
    } catch (e) {
      debugPrint("[Socket] Error flushing queue: $e");
      // Keep remaining packets in queue for next connection attempt
      _handleDisconnection();
    }
  }

  void sendText(String message) {
    if (!_isConnected || _channel == null) {
      debugPrint("[Socket] Cannot send: not connected");
      return;
    }

    try {
      _channel!.sink.add(message);
    } catch (e) {
      debugPrint("[Socket] Send error: $e");
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    if (!_isConnected) return;
    
    _isConnected = false;
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint("[Socket] Max reconnect attempts reached");
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay * (_reconnectAttempts + 1), () {
      _reconnectAttempts++;
      debugPrint("[Socket] Reconnecting (attempt $_reconnectAttempts)...");
      _connect();
    });
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        debugPrint("[Socket] Error closing: $e");
      }
      _channel = null;
    }
    
    _isConnected = false;
    debugPrint("[Socket] Disconnected (${_packetQueue.length} packets in queue)");
  }
  
  /// Clear the packet queue (useful for testing or when you want to drop queued packets)
  void clearQueue() {
    final count = _packetQueue.length;
    _packetQueue.clear();
    if (count > 0) {
      debugPrint("[Socket] Cleared $count queued packets");
    }
  }
  
  /// Parse Opus file format and return list of packets
  /// Format: [OPUS][sample_rate][frame_size][len1][opus1][len2][opus2]...
  Future<List<Uint8List>> _parseOpusFile() async {
    try {
      final ByteData data = await rootBundle.load('assets/ai.opus');
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Read header (12 bytes)
      if (bytes.length < 12) {
        debugPrint('[OPUS] File too short');
        return [];
      }
      
      // Check magic string
      final magic = String.fromCharCodes(bytes.sublist(0, 4));
      if (magic != 'OPUS') {
        debugPrint('[OPUS] Invalid magic string: $magic');
        return [];
      }
      
      // Read sample rate and frame size (little-endian uint32)
      final sampleRate = bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24);
      final frameSize = bytes[8] | (bytes[9] << 8) | (bytes[10] << 16) | (bytes[11] << 24);
      
      debugPrint('[OPUS] Sample rate: $sampleRate, Frame size: $frameSize');
      
      // Parse frames
      List<Uint8List> packets = [];
      int offset = 12;
      
      while (offset + 2 <= bytes.length) {
        // Read frame length (2 bytes, little-endian)
        final frameLen = bytes[offset] | (bytes[offset + 1] << 8);
        offset += 2;
        
        if (offset + frameLen > bytes.length) {
          debugPrint('[OPUS] Incomplete frame at offset $offset');
          break;
        }
        
        // Extract opus data
        final opusData = bytes.sublist(offset, offset + frameLen);
        offset += frameLen;
        
        // Create packet: [length (2 bytes)] + [opus data]
        final packet = Uint8List(2 + opusData.length);
        packet[0] = opusData.length & 0xFF;
        packet[1] = (opusData.length >> 8) & 0xFF;
        packet.setRange(2, 2 + opusData.length, opusData);
        
        packets.add(packet);
      }
      
      debugPrint('[OPUS] Parsed ${packets.length} packets');
      return packets;
    } catch (e) {
      debugPrint('[OPUS] Error parsing file: $e');
      return [];
    }
  }
  
  /// Send Opus file in batches via internal listener
  Future<void> sendOpusFileInBatches() async {
    if (_opusListener == null) {
      debugPrint('[OPUS] Listener not set, cannot send');
      return;
    }
    
    final listener = _opusListener!;
    final effectiveMtu = _effectiveMtu;
    
    try {
      debugPrint('[OPUS] Starting to parse file');
      
      // Parse opus file
      final packets = await _parseOpusFile();
      if (packets.isEmpty) {
        debugPrint('[OPUS] No packets to send');
        return;
      }
      
      const int repeatCount = 5;
      debugPrint('[OPUS] Starting to send ${packets.length} packets (5 times)');
      
      // Batch packets up to MTU
      List<Uint8List> batches = [];
      Uint8List currentBatch = Uint8List(0);
      
      for (final packet in packets) {
        // If adding this packet would exceed MTU and we have a batch, enqueue current batch
        if (currentBatch.isNotEmpty && currentBatch.length + packet.length > effectiveMtu) {
          batches.add(currentBatch);
          currentBatch = Uint8List(0);
        }
        
        // Add packet to current batch
        if (currentBatch.isEmpty) {
          currentBatch = Uint8List.fromList(packet);
        } else {
          final newBatch = Uint8List(currentBatch.length + packet.length);
          newBatch.setRange(0, currentBatch.length, currentBatch);
          newBatch.setRange(currentBatch.length, currentBatch.length + packet.length, packet);
          currentBatch = newBatch;
        }
      }
      
      // Add final batch if not empty
      if (currentBatch.isNotEmpty) {
        batches.add(currentBatch);
      }
      
      debugPrint('[OPUS] Created ${batches.length} batches');
      
      int totalSentBatches = 0;
      final totalBatches = batches.length * repeatCount;
      
      // Send the file 5 times
      for (int repeat = 0; repeat < repeatCount; repeat++) {
        debugPrint('[OPUS] Sending iteration ${repeat + 1}/$repeatCount');
        
        // Send batches in bursts of 5 with delay
        for (int i = 0; i < batches.length; i++) {
          // Send batch via listener (connection check is handled inside sendBatch)
          try {
            await listener.sendBatch(batches[i]);
            totalSentBatches++;
            debugPrint('[OPUS] Iteration ${repeat + 1}: Sent batch ${i + 1}/${batches.length}: ${batches[i].length} bytes');
            
            // Wait 100ms between batches
            await Future.delayed(const Duration(milliseconds: 100));
            
            // After 5 batches, wait 500ms
            if ((i + 1) % 10 == 0 && i + 1 < batches.length) {
              debugPrint('[OPUS] Sent 5 batches, waiting 500ms...');
              await Future.delayed(const Duration(milliseconds: 100));
            }
          } catch (e) {
            debugPrint('[OPUS] Error sending batch: $e');
            break;
          }
        }
        
        // Send EOF signal after each iteration (except the last one)
        // if (repeat < repeatCount - 1) {
        //   if (listener.isConnected()) {
        //     try {
        //       await Future.delayed(const Duration(milliseconds: 100));
        //       await listener.onEofReady();
        //       debugPrint('[OPUS] Sent EOF signal after iteration ${repeat + 1}');
        //       await Future.delayed(const Duration(milliseconds: 200));
        //     } catch (e) {
        //       debugPrint('[OPUS] Error sending EOF: $e');
        //     }
        //   }
        // }
      }
      
      // Send final EOF signal after all iterations (connection check is handled inside sendEof)
      try {
        await Future.delayed(const Duration(milliseconds: 100));
        await listener.sendEof();
        debugPrint('[OPUS] Sent final EOF signal');
      } catch (e) {
        debugPrint('[OPUS] Error sending final EOF: $e');
      }
      
      debugPrint('[OPUS] Finished sending: $totalSentBatches/$totalBatches batches across $repeatCount iterations');
    } catch (e) {
      debugPrint('[OPUS] Error in send: $e');
    }
  }
}


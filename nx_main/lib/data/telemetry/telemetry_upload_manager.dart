import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TelemetryUploadChunk {
  const TelemetryUploadChunk({
    required this.transferId,
    required this.sequence,
    required this.flags,
    required this.totalSize,
    required this.offset,
    required this.filename,
    required this.payload,
  });

  final int transferId;
  final int sequence;
  final int flags;
  final int totalSize;
  final int offset;
  final String filename;
  final Uint8List payload;

  bool get isLast => (flags & 0x02) != 0;
}

class _TelemetryTransferBuffer {
  _TelemetryTransferBuffer({
    required this.filename,
    required this.totalSize,
  });

  final String filename;
  final int totalSize;
  final Map<int, Uint8List> chunksByOffset = {};

  int get receivedBytes =>
      chunksByOffset.values.fold<int>(0, (sum, chunk) => sum + chunk.length);

  Uint8List? assembleIfComplete() {
    if (receivedBytes < totalSize) return null;
    final out = Uint8List(totalSize);
    final offsets = chunksByOffset.keys.toList()..sort();
    var cursor = 0;
    for (final offset in offsets) {
      final chunk = chunksByOffset[offset]!;
      if (offset != cursor || offset + chunk.length > totalSize) {
        return null;
      }
      out.setRange(offset, offset + chunk.length, chunk);
      cursor += chunk.length;
    }
    return cursor == totalSize ? out : null;
  }
}

class TelemetryUploadManager {
  TelemetryUploadManager({
    required this.httpBaseUrl,
    required this.headers,
    required this.onCommitted,
  });

  final String httpBaseUrl;
  final Map<String, String> headers;
  final Future<void> Function(int transferId) onCommitted;
  final Map<int, _TelemetryTransferBuffer> _buffers = {};

  static TelemetryUploadChunk? parsePacket(Uint8List data) {
    if (data.length < 19 || data[0] != 0x00 || data[1] != 0x02) {
      return null;
    }
    if (data[2] != 0x01) {
      return null;
    }
    final bd = ByteData.sublistView(data);
    final transferId = bd.getUint32(3, Endian.little);
    final sequence = bd.getUint16(7, Endian.little);
    final flags = data[9];
    final totalSize = bd.getUint32(10, Endian.little);
    final offset = bd.getUint32(14, Endian.little);
    final nameLen = data[18];
    final payloadStart = 19 + nameLen;
    if (nameLen == 0 || payloadStart > data.length) {
      return null;
    }
    final filename =
        utf8.decode(data.sublist(19, payloadStart), allowMalformed: true);
    return TelemetryUploadChunk(
      transferId: transferId,
      sequence: sequence,
      flags: flags,
      totalSize: totalSize,
      offset: offset,
      filename: filename,
      payload: Uint8List.fromList(data.sublist(payloadStart)),
    );
  }

  Future<void> handlePacket(Uint8List data) async {
    final chunk = parsePacket(data);
    if (chunk == null) return;

    final buffer = _buffers.putIfAbsent(
      chunk.transferId,
      () => _TelemetryTransferBuffer(
        filename: chunk.filename,
        totalSize: chunk.totalSize,
      ),
    );
    buffer.chunksByOffset[chunk.offset] = chunk.payload;

    if (!chunk.isLast) return;
    final fileBytes = buffer.assembleIfComplete();
    if (fileBytes == null) {
      debugPrint(
        '[Telemetry Upload] incomplete transfer ${chunk.transferId}: '
        '${buffer.receivedBytes}/${buffer.totalSize}',
      );
      return;
    }

    final committed =
        await _uploadFile(chunk.transferId, buffer.filename, fileBytes);
    if (committed) {
      _buffers.remove(chunk.transferId);
      await onCommitted(chunk.transferId);
    }
  }

  Future<bool> _uploadFile(
      int transferId, String filename, Uint8List bytes) async {
    final base = httpBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/telemetry/firmware/upload');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              ...headers,
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'transfer_id': transferId,
              'filename': filename,
              'origin': 'firmware',
              'format': 'jsonl',
              'content': utf8.decode(bytes, allowMalformed: true),
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
            '[Telemetry Upload] server rejected $transferId: ${response.statusCode}');
        return false;
      }
      final body = jsonDecode(response.body);
      final ok = body is Map && body['ok'] == true;
      debugPrint('[Telemetry Upload] transfer $transferId committed=$ok');
      return ok;
    } catch (e) {
      debugPrint('[Telemetry Upload] upload failed for $transferId: $e');
      return false;
    }
  }
}

Uint8List telemetryCommittedAck(int transferId) {
  final out = Uint8List(8);
  final bd = ByteData.sublistView(out);
  out[0] = 0x00;
  out[1] = 0x82;
  out[2] = 0x01;
  bd.setUint32(3, transferId, Endian.little);
  out[7] = 0x01;
  return out;
}

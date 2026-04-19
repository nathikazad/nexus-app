import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:nx_db/auth.dart';

/// Result of `POST /snapshots` with `source=expense_app` after a successful KGQL insert.
class ExpenseSnapshotUploadResult {
  const ExpenseSnapshotUploadResult({
    required this.eventId,
    required this.eventTime,
    required this.filename,
  });

  final String eventId;
  final DateTime eventTime;
  final String filename;
}

/// Local wall-clock `YYMMDDHHmmss` for the snapshot form (matches MCP `upload_snapshot`).
String expenseSnapshotTimestamp12Digits() {
  final n = DateTime.now();
  return '${(n.year % 100).toString().padLeft(2, '0')}'
      '${n.month.toString().padLeft(2, '0')}'
      '${n.day.toString().padLeft(2, '0')}'
      '${n.hour.toString().padLeft(2, '0')}'
      '${n.minute.toString().padLeft(2, '0')}'
      '${n.second.toString().padLeft(2, '0')}';
}

/// Upload image bytes to MCP HTTP [imageBaseUrl]/snapshots with `source=expense_app`.
String _normalizeImageBaseForCf(String url) {
  var ep = url;
  if (CfAccess.endpointNeedsCfAccess(ep) && ep.startsWith('http://')) {
    ep = ep.replaceFirst('http://', 'https://');
  }
  return ep;
}

Future<ExpenseSnapshotUploadResult> uploadExpenseSnapshot({
  required String imageBaseUrl,
  required String userId,
  required List<int> bytes,
  required String filename,
  required MediaType imageContentType,
}) async {
  final trimmed = imageBaseUrl.endsWith('/')
      ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
      : imageBaseUrl;
  final base = _normalizeImageBaseForCf(trimmed);
  final uri = Uri.parse('$base/snapshots');
  final req = http.MultipartRequest('POST', uri);
  req.headers['x-user-id'] = userId;
  if (CfAccess.shouldAttachHeaders(base)) {
    req.headers.addAll(CfAccess.headers);
  }
  req.fields['timestamp'] = expenseSnapshotTimestamp12Digits();
  req.fields['source'] = 'expense_app';
  final tz = DateTime.now().timeZoneName;
  req.fields['timezone'] = tz.isNotEmpty ? tz : 'UTC';
  req.files.add(
    http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: imageContentType,
    ),
  );
  final streamed = await req.send();
  final resp = await http.Response.fromStream(streamed);
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    throw StateError('Upload failed (${resp.statusCode}): ${resp.body}');
  }
  final decoded = jsonDecode(resp.body);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Invalid upload response');
  }
  if (decoded['ok'] != true) {
    throw StateError('Upload failed: ${resp.body}');
  }
  final te = decoded['timelineEvent'];
  if (te is! Map<String, dynamic>) {
    throw StateError('Missing timelineEvent after upload (KGQL insert may have failed)');
  }
  final id = te['id']?.toString();
  final timeStr = te['time']?.toString();
  if (id == null || id.isEmpty || timeStr == null || timeStr.isEmpty) {
    throw StateError('timelineEvent missing id or time');
  }
  final eventTime = DateTime.tryParse(timeStr);
  if (eventTime == null) {
    throw StateError('Invalid timelineEvent.time: $timeStr');
  }
  final fn = decoded['filename']?.toString() ?? '';
  return ExpenseSnapshotUploadResult(
    eventId: id,
    eventTime: eventTime,
    filename: fn,
  );
}

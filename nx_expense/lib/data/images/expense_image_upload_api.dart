import 'package:nx_db/app_reads.dart';
import '../sync/expense_transport.dart';
import '../sync/expense_data_repository.dart';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:nx_db/auth.dart';

/// Published receipt identity for attaching to an expense or order.
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

/// Publish through the same immutable, checksummed receipt endpoint as sync.
Future<ExpenseSnapshotUploadResult> uploadExpenseSnapshot({
  required String imageBaseUrl,
  required String userId,
  required int domainId,
  required List<int> bytes,
  required String filename,
  required MediaType imageContentType,
  required http.Client httpClient,
}) async {
  final reads = AppReads(
    httpClient,
    Uri.parse(normalizeHttpEndpoint(imageBaseUrl)),
    'expense',
    cacheResponses: false,
  );
  try {
    final result = await ExpenseTransport(reads).uploadReceipt(
      operationId: expenseOperationId(),
      domainId: domainId,
      capturedAt: DateTime.now().toIso8601String(),
      timezone: DateTime.now().timeZoneName,
      filename: filename,
      contentType: imageContentType.toString(),
      bytes: bytes,
    );
    final entity = result['entity'] as Map;
    return ExpenseSnapshotUploadResult(
      eventId: entity['event_id'].toString(),
      eventTime: DateTime.parse(entity['event_time'] as String),
      filename: result['filename'] as String,
    );
  } finally {
    await reads.close();
  }
}

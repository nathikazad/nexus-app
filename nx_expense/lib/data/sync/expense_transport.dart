import 'dart:convert';
import 'package:nx_db/app_reads.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ExpenseTransport {
  ExpenseTransport(this.reads);
  final AppReads reads;

  Future<Map<String, dynamic>> uploadReceipt({
    required String operationId,
    required int domainId,
    required String capturedAt,
    required String timezone,
    required String filename,
    required String contentType,
    required List<int> bytes,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            reads.origin.resolve('/apps/expense/receipts'),
          )
          ..fields.addAll({
            'operation_id': operationId,
            'domain_id': '$domainId',
            'captured_at': capturedAt,
            'timezone': timezone,
          })
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
              contentType: MediaType.parse(contentType),
            ),
          );
    final response = await http.Response.fromStream(
      await reads.client.send(request).timeout(const Duration(seconds: 60)),
    );
    if (response.statusCode != 200) {
      throw SyncTransportException(
        SyncFailure(
          kind: response.statusCode >= 500
              ? SyncFailureKind.transient
              : response.statusCode == 401 || response.statusCode == 403
              ? SyncFailureKind.authentication
              : SyncFailureKind.validation,
          message: 'Could not upload receipt (${response.statusCode})',
        ),
      );
    }
    final result = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (result['status'] != 'applied' || result['entity'] is! Map) {
      throw StateError('Invalid receipt acknowledgement');
    }
    reads.invalidate();
    return result;
  }

  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    final response = await reads.client
        .post(
          reads.origin.resolve('/apps/expense/commands'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(request),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw SyncTransportException(
        SyncFailure(
          kind: response.statusCode >= 500
              ? SyncFailureKind.transient
              : response.statusCode == 401 || response.statusCode == 403
              ? SyncFailureKind.authentication
              : SyncFailureKind.validation,
          message: 'Could not save expense (${response.statusCode})',
        ),
      );
    }
    final result = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (result['status'] != 'applied' && result['status'] != 'conflict') {
      throw StateError('Invalid expense acknowledgement');
    }
    reads.invalidate();
    return result;
  }
}

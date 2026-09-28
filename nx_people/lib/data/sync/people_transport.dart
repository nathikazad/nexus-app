import 'dart:convert';
import 'package:nx_db/app_reads.dart';
import 'package:nx_offline/nx_offline.dart';

class PeopleTransport {
  PeopleTransport(this.reads);
  final AppReads reads;

  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    final response = await reads.client
        .post(
          reads.origin.resolve('/apps/people/commands'),
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
          message: 'Could not save people (${response.statusCode})',
        ),
      );
    }
    final result = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (result['status'] != 'applied' && result['status'] != 'conflict') {
      throw StateError('Invalid people acknowledgement');
    }
    reads.invalidate();
    return result;
  }
}

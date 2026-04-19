import 'package:nx_expense/core/formatting/format.dart';

/// Matches expense detail: `details.counterparty.name` when present, else `"Transaction"`.
String tellerDetailHeadline(Map<String, dynamic> payload) {
  final details = payload['details'];
  if (details is Map) {
    final cp = details['counterparty'];
    if (cp is Map && cp['name'] != null) {
      final s = cp['name'].toString().trim();
      if (s.isNotEmpty) return s;
    }
  }
  return 'Transaction';
}

/// Date line for a linked Teller row (payload `date` or timeline `eventTime`).
String tellerDetailDateLabel(Map<String, dynamic> payload, DateTime eventTime) {
  final raw = payload['date']?.toString();
  if (raw != null && raw.isNotEmpty) {
    return formatModelDate(raw);
  }
  return formatModelDate(eventTime.toUtc().toIso8601String());
}

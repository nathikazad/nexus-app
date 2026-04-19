import 'package:nx_expense/domain/teller/teller_transaction.dart';

const String kTellerTimelineEventType = 'teller_transaction';
const String kTellerTimelineSource = 'teller';
const String kExpenseImageTimelineEventType = 'image';

class TellerExpenseLink {
  const TellerExpenseLink({
    required this.linkId,
    required this.eventTime,
    required this.eventId,
    required this.payload,
    this.eventType,
  });

  final String linkId;
  final DateTime eventTime;
  final String eventId;
  final Map<String, dynamic> payload;

  /// From `timeline_events.event_type` when present; null treated as Teller for older rows.
  final String? eventType;

  bool get isTellerTimelineEvent =>
      eventType == null || eventType == kTellerTimelineEventType;

  bool get isBillImageEvent => eventType == kExpenseImageTimelineEventType;

  TellerTransaction toTellerTransaction() {
    return TellerTransaction(
      time: eventTime,
      eventId: eventId,
      payload: payload,
      linkedModels: const [],
    );
  }
}

class LinkedTellerModel {
  const LinkedTellerModel({
    required this.id,
    required this.name,
    required this.modelTypeName,
    this.linkId,
  });

  final int id;
  final String name;
  final String modelTypeName;

  /// `model_timeline_event_links.id` for delete mutations.
  final String? linkId;
}

class TellerTransaction {
  const TellerTransaction({
    required this.time,
    required this.eventId,
    required this.payload,
    required this.linkedModels,
    this.source,
    this.eventType,
  });

  final DateTime time;
  final String eventId;
  final Map<String, dynamic> payload;
  final List<LinkedTellerModel> linkedModels;
  final String? source;
  final String? eventType;
}

/// Legacy name kept for routes and widgets during the nx_expense layer reorg.
typedef TellerTransactionRow = TellerTransaction;

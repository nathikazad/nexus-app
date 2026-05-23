class TellerSyncResult {
  const TellerSyncResult({required this.expenseReview});

  final TellerExpenseReview? expenseReview;

  factory TellerSyncResult.fromJson(Map<String, dynamic> json) {
    final rawReview = json['expense_review'];
    return TellerSyncResult(
      expenseReview: rawReview is Map
          ? TellerExpenseReview.fromJson(Map<String, dynamic>.from(rawReview))
          : null,
    );
  }
}

class TellerExpenseReview {
  const TellerExpenseReview({
    required this.domainId,
    required this.summary,
    required this.items,
  });

  final int domainId;
  final Map<String, dynamic> summary;
  final List<TellerExpenseReviewItem> items;

  factory TellerExpenseReview.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return TellerExpenseReview(
      domainId: _asInt(json['domain_id']) ?? 2,
      summary: _asStringMap(json['summary']) ?? const {},
      items: rawItems is List
          ? [
              for (final raw in rawItems)
                if (raw is Map)
                  TellerExpenseReviewItem.fromJson(
                    Map<String, dynamic>.from(raw),
                  ),
            ]
          : const [],
    );
  }
}

class TellerExpenseReviewItem {
  const TellerExpenseReviewItem({
    required this.reviewId,
    required this.event,
    required this.transaction,
    required this.suggestedExpense,
    required this.candidateExistingExpenses,
    required this.recommendedAction,
    required this.availableActions,
  });

  final String reviewId;
  final TellerReviewEvent event;
  final TellerReviewTransaction transaction;
  final TellerSuggestedExpense suggestedExpense;
  final List<TellerExistingExpenseCandidate> candidateExistingExpenses;
  final String recommendedAction;
  final List<String> availableActions;

  factory TellerExpenseReviewItem.fromJson(Map<String, dynamic> json) {
    final rawEvent = _asStringMap(json['event']) ?? const {};
    final rawTransaction = _asStringMap(json['transaction']) ?? const {};
    final rawSuggested = _asStringMap(json['suggested_expense']) ?? const {};
    final rawCandidates = json['candidate_existing_expenses'];
    final rawActions = json['available_actions'];
    return TellerExpenseReviewItem(
      reviewId: json['review_id']?.toString() ?? '',
      event: TellerReviewEvent.fromJson(rawEvent),
      transaction: TellerReviewTransaction.fromJson(rawTransaction),
      suggestedExpense: TellerSuggestedExpense.fromJson(rawSuggested),
      candidateExistingExpenses: rawCandidates is List
          ? [
              for (final raw in rawCandidates)
                if (raw is Map)
                  TellerExistingExpenseCandidate.fromJson(
                    Map<String, dynamic>.from(raw),
                  ),
            ]
          : const [],
      recommendedAction: json['recommended_action']?.toString() ?? 'review',
      availableActions: rawActions is List
          ? [for (final raw in rawActions) raw.toString()]
          : const ['create_expense', 'link_existing_expense', 'skip'],
    );
  }

  Map<String, dynamic> createExpenseDecision() => {
    'review_id': reviewId,
    'event_id': event.eventId,
    'action': 'create_expense',
    'expense': suggestedExpense.toApplyJson(),
  };

  Map<String, dynamic> linkExistingDecision(int expenseId) => {
    'review_id': reviewId,
    'event_id': event.eventId,
    'action': 'link_existing_expense',
    'existing_expense_id': expenseId,
  };

  Map<String, dynamic> skipDecision() => {
    'review_id': reviewId,
    'event_id': event.eventId,
    'action': 'skip',
    'reason': 'user_review_skip',
  };
}

class TellerReviewEvent {
  const TellerReviewEvent({required this.eventId, this.eventTime});

  final int eventId;
  final String? eventTime;

  factory TellerReviewEvent.fromJson(Map<String, dynamic> json) =>
      TellerReviewEvent(
        eventId: _asInt(json['event_id']) ?? 0,
        eventTime: json['event_time']?.toString(),
      );
}

class TellerReviewTransaction {
  const TellerReviewTransaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.counterpartyName,
    required this.type,
  });

  final String? id;
  final String? date;
  final num? amount;
  final String description;
  final String? counterpartyName;
  final String? type;

  factory TellerReviewTransaction.fromJson(Map<String, dynamic> json) =>
      TellerReviewTransaction(
        id: json['id']?.toString(),
        date: json['date']?.toString(),
        amount: _asNum(json['amount']),
        description: json['description']?.toString() ?? '',
        counterpartyName: json['counterparty_name']?.toString(),
        type: json['type']?.toString(),
      );
}

class TellerSuggestedExpense {
  const TellerSuggestedExpense({
    required this.name,
    required this.description,
    required this.cost,
    required this.date,
    required this.companyId,
    required this.companyName,
    required this.tags,
  });

  final String name;
  final String description;
  final num? cost;
  final String? date;
  final int? companyId;
  final String? companyName;
  final List<TellerReviewTag> tags;

  factory TellerSuggestedExpense.fromJson(Map<String, dynamic> json) {
    final company = _asStringMap(json['company']);
    final rawTags = json['tags'];
    return TellerSuggestedExpense(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      cost: _asNum(json['cost']),
      date: json['date']?.toString(),
      companyId: _asInt(company?['existing_company_id']),
      companyName: company?['name']?.toString(),
      tags: rawTags is List
          ? [
              for (final raw in rawTags)
                if (raw is Map)
                  TellerReviewTag.fromJson(Map<String, dynamic>.from(raw)),
            ]
          : const [],
    );
  }

  Map<String, dynamic> toApplyJson() => {
    'name': name,
    'description': description,
    'cost': cost?.toString(),
    'date': date,
    if (companyId != null) 'company_id': companyId,
    if (companyId == null && companyName != null) 'company_name': companyName,
    'tags': [for (final tag in tags) tag.toApplyJson()],
  };
}

class TellerReviewTag {
  const TellerReviewTag({
    required this.system,
    required this.path,
    required this.tagNodeId,
  });

  final String system;
  final List<String> path;
  final int? tagNodeId;

  String get label => [system, ...path].where((s) => s.isNotEmpty).join(' / ');

  factory TellerReviewTag.fromJson(Map<String, dynamic> json) {
    final rawPath = json['path'];
    return TellerReviewTag(
      system: json['system']?.toString() ?? '',
      path: rawPath is List ? [for (final raw in rawPath) raw.toString()] : [],
      tagNodeId: _asInt(json['tag_node_id']),
    );
  }

  Map<String, dynamic> toApplyJson() => {
    'system': system,
    'path': path,
    'tag_node_id': tagNodeId,
  };
}

class TellerExistingExpenseCandidate {
  const TellerExistingExpenseCandidate({
    required this.modelId,
    required this.name,
    required this.cost,
    required this.date,
    required this.companyName,
  });

  final int modelId;
  final String name;
  final num? cost;
  final String? date;
  final String? companyName;

  factory TellerExistingExpenseCandidate.fromJson(Map<String, dynamic> json) {
    final company = _asStringMap(json['company']);
    return TellerExistingExpenseCandidate(
      modelId: _asInt(json['model_id']) ?? 0,
      name: json['name']?.toString() ?? 'Expense',
      cost: _asNum(json['cost']),
      date: json['date']?.toString(),
      companyName: company?['name']?.toString(),
    );
  }
}

class TellerExpenseReviewApplyResult {
  const TellerExpenseReviewApplyResult({
    required this.counts,
    required this.results,
  });

  final Map<String, dynamic> counts;
  final List<Map<String, dynamic>> results;

  factory TellerExpenseReviewApplyResult.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    return TellerExpenseReviewApplyResult(
      counts: _asStringMap(json['counts']) ?? const {},
      results: rawResults is List
          ? [
              for (final raw in rawResults)
                if (raw is Map) Map<String, dynamic>.from(raw),
            ]
          : const [],
    );
  }
}

Map<String, dynamic>? _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

num? _asNum(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  return null;
}

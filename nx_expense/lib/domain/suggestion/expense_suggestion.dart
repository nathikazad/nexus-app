class ExpenseSuggestion {
  const ExpenseSuggestion({
    required this.id,
    required this.caseKey,
    required this.status,
    required this.title,
    required this.reason,
    required this.bankTransactions,
    required this.provider,
    required this.expense,
    required this.tags,
    required this.products,
    this.changes = const [],
  });

  final int id;
  final String caseKey;
  final String status;
  final String title;
  final String reason;
  final List<SuggestionEvent> bankTransactions;
  final SuggestionEvent? provider;
  final SuggestedExpense expense;
  final List<SuggestedTag> tags;
  final List<SuggestedProduct> products;
  final List<SuggestionChange> changes;

  bool get createsExpense => expense.id == null;
  bool get hasProvider => provider != null;
  num? get displayAmount {
    if (expense.cost != null) return expense.cost;
    if (bankTransactions.any((event) => event.amount == null)) return null;
    return bankTransactions.fold<num>(0, (sum, event) => sum + event.amount!);
  }

  factory ExpenseSuggestion.fromJson(Map<String, dynamic> json) {
    final content = _map(json['content']);
    final evidence = _map(content['evidence']);
    final proposal = _map(content['proposal']);
    final model = _map(proposal['model']);
    final updates = _mapOrNull(proposal['updates']);
    final relations = _maps(model['relations']);
    final existingExpense = _mapOrNull(evidence['existing_expense']);
    final modelId = _int(model['id']);
    final modelName = _text(model['name']);
    final nameUpdate = _mapOrNull(updates?['name']);
    final expenseName =
        _text(nameUpdate?['to']) ??
        modelName ??
        _text(existingExpense?['name']) ??
        _text(existingExpense?['description']) ??
        'Existing expense';

    final bankTransactions = _maps(evidence['bank_transactions'])
        .map((item) => SuggestionEvent.fromJson(item, fallbackSource: 'bank'))
        .toList();
    if (bankTransactions.isEmpty) {
      throw const FormatException('suggestion has no bank transactions');
    }
    final providerMap = _mapOrNull(evidence['provider']);

    return ExpenseSuggestion(
      id: _int(json['id']) ?? 0,
      caseKey: _text(json['case_key']) ?? '',
      status: _text(json['status']) ?? 'open',
      title: _text(content['title']) ?? 'Review suggestion',
      reason: _text(content['reason']) ?? '',
      bankTransactions: bankTransactions,
      provider: providerMap == null
          ? null
          : SuggestionEvent.fromJson(providerMap, fallbackSource: 'provider'),
      expense: SuggestedExpense(
        id: modelId,
        name: expenseName,
        cost: _attributeNumber(model, 'cost'),
        date: _attributeText(model, 'date'),
        ignore: _attributeBool(model, 'ignore'),
        companyName: _relationTargetName(relations, 'expense_for'),
      ),
      tags: _maps(model['tags']).map(SuggestedTag.fromJson).toList(),
      products: relations
          .where((relation) => relation['relation_name'] == 'includes_product')
          .map(SuggestedProduct.fromRelation)
          .toList(),
      changes: _suggestionChanges(updates),
    );
  }
}

class SuggestionChange {
  const SuggestionChange({required this.field, this.before, this.after});

  final String field;
  final String? before;
  final String? after;
}

class SuggestionEvent {
  const SuggestionEvent({
    required this.eventId,
    required this.source,
    required this.eventType,
    required this.description,
    this.date,
    this.amount,
    this.accountLast4,
    this.orderIds = const [],
  });

  final int? eventId;
  final String source;
  final String eventType;
  final String description;
  final String? date;
  final num? amount;
  final String? accountLast4;
  final List<String> orderIds;

  factory SuggestionEvent.fromJson(
    Map<String, dynamic> json, {
    required String fallbackSource,
  }) {
    final evidence = _mapOrNull(json['evidence']);
    final rawOrders = evidence?['order_ids'];
    return SuggestionEvent(
      eventId: _int(json['event_id']),
      source: _text(json['source']) ?? fallbackSource,
      eventType: _text(json['event_type']) ?? 'transaction',
      description:
          _text(json['summary']) ??
          _text(json['description']) ??
          _text(json['message']) ??
          _text(evidence?['description']) ??
          'Transaction',
      date: _text(json['date']) ?? _dateFromTimestamp(json['event_time']),
      amount: _number(json['amount']),
      accountLast4: _last4(json['account_last4']),
      orderIds: rawOrders is List
          ? rawOrders
                .map((value) => '$value')
                .where((value) => value.isNotEmpty)
                .toList()
          : const [],
    );
  }
}

class SuggestedExpense {
  const SuggestedExpense({
    required this.id,
    required this.name,
    this.cost,
    this.date,
    this.ignore,
    this.companyName,
  });

  final int? id;
  final String name;
  final num? cost;
  final String? date;
  final bool? ignore;
  final String? companyName;
}

class SuggestedTag {
  const SuggestedTag({required this.system, required this.path});

  final String system;
  final List<String> path;

  String get label => path.join(' / ');

  factory SuggestedTag.fromJson(Map<String, dynamic> json) {
    final rawPath = json['path'];
    return SuggestedTag(
      system: _text(json['system']) ?? 'Tag',
      path: rawPath is List
          ? rawPath.map((value) => '$value').toList()
          : const [],
    );
  }
}

class SuggestedProduct {
  const SuggestedProduct({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.imageUrl,
    required this.maker,
  });

  final int? id;
  final String name;
  final num? quantity;
  final String? unit;
  final num? price;
  final String? imageUrl;
  final SuggestedCompany? maker;

  bool get createsProduct => id == null;

  factory SuggestedProduct.fromRelation(Map<String, dynamic> relation) {
    final target = _map(relation['target']);
    final targetRelations = _maps(target['relations']);
    final makerRelation = targetRelations
        .where((item) => item['relation_name'] == 'made_by')
        .firstOrNull;
    final makerTarget = makerRelation == null
        ? null
        : _map(makerRelation['target']);
    return SuggestedProduct(
      id: _int(target['id']),
      name: _text(target['name']) ?? 'Product',
      quantity: _relationAttributeNumber(relation, 'quantity'),
      unit: _relationAttributeText(relation, 'unit'),
      price: _relationAttributeNumber(relation, 'price'),
      imageUrl: _localProductImageUrl(_attributeText(target, 'image_url')),
      maker: makerTarget == null
          ? null
          : SuggestedCompany(
              id: _int(makerTarget['id']),
              name: _text(makerTarget['name']) ?? 'Company',
            ),
    );
  }
}

class SuggestedCompany {
  const SuggestedCompany({required this.id, required this.name});

  final int? id;
  final String name;

  bool get createsCompany => id == null;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic>? _mapOrNull(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

num? _number(dynamic value) {
  if (value is num) return value;
  return num.tryParse(
    '${value ?? ''}'.replaceAll(',', '').replaceAll(r'$', '').trim(),
  );
}

String? _last4(dynamic value) {
  final digits = '${value ?? ''}'.replaceAll(RegExp(r'\D'), '');
  return digits.length < 4 ? null : digits.substring(digits.length - 4);
}

String? _localProductImageUrl(String? value) {
  if (value == null) return null;
  final valid = RegExp(
    r'^/amazon/item_thumbnails/[1-9][0-9]*/[A-Za-z0-9][A-Za-z0-9._-]*\.(?:jpg|jpeg|png|webp)$',
    caseSensitive: false,
  );
  return valid.hasMatch(value) ? value : null;
}

String? _dateFromTimestamp(dynamic value) {
  final parsed = DateTime.tryParse('${value ?? ''}');
  if (parsed == null) return null;
  return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}

List<SuggestionChange> _suggestionChanges(Map<String, dynamic>? updates) {
  if (updates == null) return const [];
  final changes = <SuggestionChange>[];
  final name = _mapOrNull(updates['name']);
  if (name != null) {
    changes.add(
      SuggestionChange(
        field: 'Name',
        before: _displayValue(name['from']),
        after: _displayValue(name['to']),
      ),
    );
  }
  for (final attribute in _maps(updates['attributes'])) {
    final key = _text(attribute['key']);
    if (key == null) continue;
    changes.add(
      SuggestionChange(
        field: switch (key) {
          'cost' => 'Cost',
          'date' => 'Date',
          'ignore' => 'Ignore',
          _ => key,
        },
        before: _displayValue(attribute['from']),
        after: _displayValue(attribute['to']),
      ),
    );
  }
  final tags = _mapOrNull(updates['tags']);
  for (final tag in _maps(tags?['remove'])) {
    changes.add(
      SuggestionChange(
        field: 'Remove tag',
        before: SuggestedTag.fromJson(tag).label,
      ),
    );
  }
  for (final tag in _maps(tags?['add'])) {
    changes.add(
      SuggestionChange(
        field: 'Add tag',
        after: SuggestedTag.fromJson(tag).label,
      ),
    );
  }
  return changes;
}

String? _displayValue(dynamic value) {
  if (value == null) return 'Not set';
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is num) return '$value';
  return _text(value);
}

dynamic _attributeValue(Map<String, dynamic> model, String key) {
  for (final attribute in _maps(model['attributes'])) {
    if (attribute['key'] == key) return attribute['value'];
  }
  return null;
}

String? _attributeText(Map<String, dynamic> model, String key) =>
    _text(_attributeValue(model, key));

num? _attributeNumber(Map<String, dynamic> model, String key) =>
    _number(_attributeValue(model, key));

bool? _attributeBool(Map<String, dynamic> model, String key) {
  final value = _attributeValue(model, key);
  return value is bool ? value : null;
}

dynamic _relationAttributeValue(Map<String, dynamic> relation, String key) {
  for (final attribute in _maps(relation['attributes'])) {
    if (attribute['key'] == key) return attribute['value'];
  }
  return null;
}

String? _relationAttributeText(Map<String, dynamic> relation, String key) =>
    _text(_relationAttributeValue(relation, key));

num? _relationAttributeNumber(Map<String, dynamic> relation, String key) =>
    _number(_relationAttributeValue(relation, key));

String? _relationTargetName(
  List<Map<String, dynamic>> relations,
  String relationName,
) {
  for (final relation in relations) {
    if (relation['relation_name'] == relationName) {
      return _text(_map(relation['target'])['name']);
    }
  }
  return null;
}

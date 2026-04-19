import 'package:nx_db/kgql.dart' show Model, ModelType;

import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/data/expense/expense_attr_keys.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/domain/transfer/transfer.dart';

/// Row title: Cash when `to` is Cash; otherwise linked Company name or model name.
String transferDisplayTitle(dynamic model) {
  final String name;
  final Map<String, dynamic>? attributes;
  final Map<String, List<RelatedModel>>? relations;
  if (model is Transfer) {
    name = model.name;
    attributes = model.attributes;
    relations = model.relations;
  } else if (model is RelatedModel) {
    name = model.name;
    attributes = model.attributes;
    relations = model.relations;
  } else {
    throw ArgumentError.value(model, 'model', 'transferDisplayTitle');
  }
  final to = attributes?['to'];
  if (to is String && to.toLowerCase() == 'cash') {
    return 'Cash';
  }
  final companies = relations?['Company'];
  if (companies != null && companies.isNotEmpty) {
    return companies.first.name;
  }
  return name;
}

num? transferAmountAttribute(dynamic model) {
  Map<String, dynamic>? attributes;
  if (model is Transfer) {
    attributes = model.attributes;
  } else if (model is RelatedModel) {
    attributes = model.attributes;
  } else {
    throw ArgumentError.value(model, 'model', 'transferAmountAttribute');
  }
  final raw = attributes?['amount'];
  if (raw is num) return raw;
  return num.tryParse('$raw');
}

String expenseDateSortKey(Expense m) {
  final raw = m.attributes?['date'];
  if (raw is String && raw.isNotEmpty) return normalizeDateAttributeSortKey(raw);
  return m.createdAt ?? '';
}

String transferDateSortKey(Transfer m) {
  final raw = m.attributes?['date'];
  if (raw is String && raw.isNotEmpty) return normalizeDateAttributeSortKey(raw);
  return m.createdAt ?? '';
}

String expenseDateCellLabel(Expense model) {
  final raw = model.attributes?['date'];
  if (raw is String && raw.isNotEmpty) return formatModelDate(raw);
  return formatModelDate(model.createdAt);
}

String transferCellDateLabel(dynamic model) {
  Map<String, dynamic>? attributes;
  String? createdAt;
  if (model is Transfer) {
    attributes = model.attributes;
    createdAt = model.createdAt;
  } else if (model is RelatedModel) {
    attributes = model.attributes;
    createdAt = model.createdAt;
  } else {
    throw ArgumentError.value(model, 'model', 'transferCellDateLabel');
  }
  final raw = attributes?['date'];
  if (raw is String && raw.isNotEmpty) return formatModelDate(raw);
  return formatModelDate(createdAt);
}

/// Reads [attributes] for expense / transfer / KGQL [Model] / [RelatedModel].
dynamic attributeValue(dynamic model, String? key) {
  if (key == null) return null;
  if (model is Expense) return model.attributes?[key];
  if (model is Transfer) return model.attributes?[key];
  if (model is RelatedModel) return model.attributes?[key];
  if (model is Model) return model.attributes?[key];
  return null;
}

/// First number attribute key on [ModelTypeView] or KGQL [ModelType].
String? primaryNumberAttributeKey(dynamic schema) {
  if (schema is ModelTypeView) return schema.primaryNumberAttributeKey;
  if (schema is ModelType) {
    final attrs = schema.attributes;
    if (attrs == null) return null;
    for (final ad in attrs) {
      final k = ad.key;
      if (ad.valueType == 'number' && k != null && k.isNotEmpty) return k;
    }
  }
  return null;
}

String modelDateCellLabel(dynamic model) {
  if (model is Expense) return expenseDateCellLabel(model);
  if (model is Transfer) return transferCellDateLabel(model);
  if (model is RelatedModel) {
    final raw = model.attributes?['date'];
    if (raw is String && raw.isNotEmpty) return formatModelDate(raw);
    return formatModelDate(model.createdAt);
  }
  if (model is Model) {
    final raw = model.attributes?['date'];
    if (raw is String && raw.isNotEmpty) return formatModelDate(raw);
    return formatModelDate(model.createdAt);
  }
  return '—';
}

String modelDateSortKey(dynamic model) {
  if (model is Expense) return expenseDateSortKey(model);
  if (model is Transfer) return transferDateSortKey(model);
  if (model is RelatedModel) {
    final raw = model.attributes?['date'];
    if (raw is String && raw.isNotEmpty) {
      return normalizeDateAttributeSortKey(raw);
    }
    return model.createdAt ?? '';
  }
  if (model is Model) {
    final raw = model.attributes?['date'];
    if (raw is String && raw.isNotEmpty) {
      return normalizeDateAttributeSortKey(raw);
    }
    return model.createdAt ?? '';
  }
  return '';
}

List<Model> sortModelsByDateDesc(List<Model> models) {
  final out = [...models];
  out.sort((a, b) => modelDateSortKey(b).compareTo(modelDateSortKey(a)));
  return out;
}

List<T> dedupeModelsById<T>(List<T> models) {
  int idOf(T m) {
    if (m is Model) return m.id;
    if (m is RelatedModel) return m.id;
    throw ArgumentError.value(m, 'm', 'dedupeModelsById: unsupported type');
  }

  final seen = <int>{};
  return [for (final m in models) if (seen.add(idOf(m))) m];
}

/// Display label for a schema attribute key (`cost`, `date-time`, `snake_case` → title words).
String formatAttributeLabel(String key) {
  if (key.isEmpty) return key;
  final parts = key.split(RegExp(r'[-_\s]+')).where((s) => s.isNotEmpty);
  return parts
      .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
      .join(' ');
}

bool expenseIgnoredForTotals(Expense model) {
  final v = model.attributes?[kExpenseIgnoreAttributeKey];
  if (v == true) return true;
  if (v == false) return false;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == 'true' || s == '1';
  }
  return false;
}

List<int> dedupeIntIdsPreserveOrder(List<int> ids) {
  final seen = <int>{};
  return [for (final id in ids) if (seen.add(id)) id];
}

List<Expense> dedupeExpensesById(List<Expense> models) {
  final seen = <int>{};
  return [for (final m in models) if (seen.add(m.id)) m];
}

bool relationPendingCreateEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

bool relationStateMatchesSnapshotForUpdate({
  required Map<String, List<int>> linkIdsByType,
  required Map<String, Map<String, dynamic>?> createsByType,
  required Map<String, Set<int>> snapshotLinkIdsByType,
  required Map<String, Map<String, dynamic>?> snapshotCreatesByType,
}) {
  for (final k in linkIdsByType.keys) {
    final curIds = dedupeIntIdsPreserveOrder(linkIdsByType[k] ?? []).toSet();
    final snapIds = snapshotLinkIdsByType[k] ?? <int>{};
    if (curIds.length != snapIds.length ||
        !curIds.containsAll(snapIds) ||
        !snapIds.containsAll(curIds)) {
      return false;
    }
    if (!relationPendingCreateEquals(createsByType[k], snapshotCreatesByType[k])) {
      return false;
    }
  }
  return true;
}

bool shouldOmitRelationsOnExpenseUpdate({
  required int? expenseId,
  required Map<String, List<int>> linkIdsByType,
  required Map<String, Map<String, dynamic>?> createsByType,
  required Map<String, Set<int>> snapshotLinkIdsByType,
  required Map<String, Map<String, dynamic>?> snapshotCreatesByType,
}) {
  if (expenseId == null) return false;
  return relationStateMatchesSnapshotForUpdate(
    linkIdsByType: linkIdsByType,
    createsByType: createsByType,
    snapshotLinkIdsByType: snapshotLinkIdsByType,
    snapshotCreatesByType: snapshotCreatesByType,
  );
}

List<Expense> sortExpensesByDateDesc(List<Expense> models) {
  final out = [...models];
  out.sort((a, b) => expenseDateSortKey(b).compareTo(expenseDateSortKey(a)));
  return out;
}

/// Parse `getKgqlAggregate` maps for chart labels/values (shape varies by backend).
List<MapEntry<String, double>> parseGroupedChartEntries(Map<String, dynamic> raw) {
  final g = raw['grouped'];
  if (g is! List) return [];
  final out = <MapEntry<String, double>>[];
  for (final item in g) {
    if (item is Map) {
      final m = Map<String, dynamic>.from(item);
      final label = (m['group_key'] ?? m['name'] ?? m['label'] ?? m['key'] ?? '').toString();
      final v = m['aggregated_value'] ?? m['value'];
      if (label.isEmpty) continue;
      if (v is num) {
        out.add(MapEntry(label, v.toDouble()));
      }
    }
  }
  return out;
}

/// Appends an "Other" entry for the residual between [totalSpendSigned] and the
/// sum of [entries] returned by a grouped aggregate. Used to surface
/// uncategorized spend in tag/relation pie charts (the backend only returns
/// categories that have data). Returns [entries] unchanged when the residual is
/// zero or the total is unknown. If an "Other" entry already exists it is
/// merged rather than duplicated.
List<MapEntry<String, double>> appendOtherResidualEntry(
  List<MapEntry<String, double>> entries,
  num? totalSpendSigned, {
  double epsilon = 0.005,
  String otherLabel = 'Other',
}) {
  if (totalSpendSigned == null) return entries;
  final sum = entries.fold<double>(0, (a, b) => a + b.value);
  final other = totalSpendSigned.toDouble() - sum;
  if (other.abs() < epsilon) return entries;
  final out = <MapEntry<String, double>>[];
  var merged = false;
  for (final e in entries) {
    if (e.key == otherLabel) {
      out.add(MapEntry(otherLabel, e.value + other));
      merged = true;
    } else {
      out.add(e);
    }
  }
  if (!merged) out.add(MapEntry(otherLabel, other));
  return out;
}

List<MapEntry<String, double>> parseDaySpendEntries(Map<String, dynamic> raw) {
  final g = raw['grouped'];
  if (g is! List) return [];
  final out = <MapEntry<String, double>>[];
  for (final item in g) {
    if (item is Map) {
      final m = Map<String, dynamic>.from(item);
      final label = (m['group_key'] ??
              m['key'] ??
              m['name'] ??
              m['label'] ??
              m['day'] ??
              m['date'] ??
              m['created_at'] ??
              '')
          .toString();
      final v = m['aggregated_value'] ?? m['value'];
      if (label.isEmpty) continue;
      if (v is num) {
        out.add(MapEntry(label, v.toDouble()));
      }
    }
  }
  if (out.isEmpty && raw['aggregated_value'] is num) {
    return [MapEntry('total', (raw['aggregated_value'] as num).toDouble())];
  }
  return out;
}

double numAttr(Expense m, String key) {
  final raw = m.attributes?[key];
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw') ?? 0;
}

double numAttrTransfer(Transfer m, String key) {
  final raw = m.attributes?[key];
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw') ?? 0;
}
